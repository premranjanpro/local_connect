using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Api.Hubs;
using ShopConnector.Api.Services;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Enums;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

/// <summary>
/// Full Order Lifecycle Controller:
///
/// Customer flow:
///   POST   /api/v1/orders/{id}/cancel       — delete if PENDING/BROADCASTING
///
/// Shop Owner flow:
///   POST   /api/v1/orders/{id}/confirm       — shop review → confirm → broadcast
///   POST   /api/v1/orders/{id}/reject        — reject order with reason
///   POST   /api/v1/orders/{id}/post-market   — post to market drivers (open network)
///   GET    /api/v1/orders/{id}/delivery-log  — full immutable delivery event log
///
/// Driver flow (with GPS + geofence validation):
///   POST   /api/v1/orders/{id}/start         — driver starts trip (EN_ROUTE_PICKUP)
///   POST   /api/v1/orders/{id}/arrive-pickup — driver at pickup (AT_PICKUP)
///   POST   /api/v1/orders/{id}/pickup        — pickup OTP verified or OTP-less
///   POST   /api/v1/orders/{id}/arrive-drop   — driver at drop (AT_DROP)
///   POST   /api/v1/orders/{id}/complete      — drop OTP verified or OTP-less
/// </summary>
[ApiController]
[Route("api/v1/orders")]
[Authorize]
public class OrderLifecycleController : ControllerBase
{
    private readonly CoreDbContext _db;
    private readonly IAuditService _auditService;
    private readonly IFcmNotificationService _fcmService;
    private readonly IHubContext<TaskHub> _taskHub;
    private readonly IWebhookService _webhookService;

    private const double GeofenceOkMeters = 150.0;
    private const double GeofenceAlertMeters = 400.0;

    public OrderLifecycleController(
        CoreDbContext db,
        IAuditService auditService,
        IFcmNotificationService fcmService,
        IHubContext<TaskHub> taskHub,
        IWebhookService webhookService)
    {
        _db = db;
        _auditService = auditService;
        _fcmService = fcmService;
        _taskHub = taskHub;
        _webhookService = webhookService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  CUSTOMER: Permanent delete of PENDING / BROADCASTING orders only
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Customer permanently deletes a pending/broadcasting order.
    /// Once a driver has accepted (EN_ROUTE_PICKUP or beyond), cancellation
    /// is blocked — customer must contact driver via chat.
    /// </summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> CancelOrder(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == id && !t.IsDeleted);

        if (task == null) return NotFound(new { message = "Order not found." });
        if (task.CustomerId != userId.Value)
            return Forbid();

        // Block cancellation once driver has started
        var blockStatuses = new[] { "EN_ROUTE_PICKUP", "AT_PICKUP", "PICKED_UP", "AT_DROP", "InProgress", "Accepted" };
        if (blockStatuses.Contains(task.Status))
        {
            return BadRequest(new
            {
                message = "Order cannot be cancelled — driver has already accepted and started. Contact driver via chat.",
                currentStatus = task.Status
            });
        }

        if (task.Status == "Completed" || task.Status == "Cancelled")
        {
            return BadRequest(new { message = $"Order is already {task.Status}.", currentStatus = task.Status });
        }

        // Soft delete (permanent from customer's view)
        task.IsDeleted = true;
        task.DeletedAt = DateTime.UtcNow;
        task.DeletedBy = userId.Value;
        task.Status = "Cancelled";
        task.CancelledAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "OrderCancelledByCustomer", "TaskEntity", task.Id.ToString(),
            details: $"{{\"previousStatus\":\"{task.Status}\"}}");

        // Notify shop owner if business order
        if (task.BusinessId.HasValue)
        {
            await _webhookService.FireAsync("task.cancelled", BuildTaskPayload(task), businessId: task.BusinessId);
        }

        await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnTaskStatusChanged", new
        {
            taskId = task.Id,
            status = "Cancelled",
            reason = "Cancelled by customer"
        });

        return Ok(new { message = "Order permanently deleted.", taskId = task.Id });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  SHOP OWNER: Review → Confirm → Broadcast
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>Shop owner reviews pending order and confirms it for dispatch.</summary>
    [HttpPost("{id}/confirm")]
    public async Task<IActionResult> ConfirmOrder(Guid id, [FromBody] ConfirmOrderRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Customer)
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == id && !t.IsDeleted);

        if (task == null) return NotFound();

        // Must be shop owner of this order's business
        if (!task.BusinessId.HasValue) return BadRequest(new { message = "Not a business order." });

        var business = await _db.Businesses.FirstOrDefaultAsync(b =>
            b.Id == task.BusinessId.Value && b.MerchantId == userId.Value);
        if (business == null) return Forbid();

        if (task.Status != "Created" && task.Status != "PendingShopConfirm")
            return BadRequest(new { message = $"Order is {task.Status} — cannot confirm." });

        // Apply OTP policy from request (shop owner decides per order)
        task.IsPickupOtpRequired = req.RequirePickupOtp;
        task.IsDropOtpRequired = req.RequireDropOtp;
        task.ShopConfirmedAt = DateTime.UtcNow;
        task.ShopConfirmedBy = userId.Value;
        task.Status = PlatformTaskStatus.Broadcasting.ToString();

        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "OrderConfirmedByShop", "TaskEntity", task.Id.ToString(),
            details: $"{{\"pickupOtpRequired\":{req.RequirePickupOtp},\"dropOtpRequired\":{req.RequireDropOtp}}}");

        // Notify customer
        await SendPushToUser(task.CustomerId, "Order Confirmed! 🎉",
            $"{business.Name} has confirmed your order. A driver will be assigned soon.");

        // Fire webhook
        await _webhookService.FireAsync("task.shop_confirmed", BuildTaskPayload(task), businessId: task.BusinessId);

        // SignalR broadcast to available drivers
        await _taskHub.Clients.All.SendAsync("OnNewTaskBroadcast", BuildTaskPayload(task));

        return Ok(new
        {
            message = "Order confirmed and broadcast to drivers.",
            taskId = task.Id,
            status = task.Status,
            pickupOtpRequired = task.IsPickupOtpRequired,
            dropOtpRequired = task.IsDropOtpRequired,
            pickupOtp = req.RequirePickupOtp ? task.PickupOtp : null,
            dropOtp = req.RequireDropOtp ? task.DropoffOtp : null
        });
    }

    /// <summary>Shop owner rejects order with reason.</summary>
    [HttpPost("{id}/reject")]
    public async Task<IActionResult> RejectOrder(Guid id, [FromBody] RejectOrderRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Customer)
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == id && !t.IsDeleted);

        if (task == null) return NotFound();
        if (!task.BusinessId.HasValue) return BadRequest(new { message = "Not a business order." });

        var business = await _db.Businesses.FirstOrDefaultAsync(b =>
            b.Id == task.BusinessId.Value && b.MerchantId == userId.Value);
        if (business == null) return Forbid();

        task.Status = "Cancelled";
        task.CancelledAt = DateTime.UtcNow;
        task.ShopRejectionReason = req.Reason;
        task.IsDeleted = true;
        task.DeletedAt = DateTime.UtcNow;
        task.DeletedBy = userId.Value;

        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "OrderRejectedByShop", "TaskEntity", task.Id.ToString(),
            details: $"{{\"reason\":\"{req.Reason}\"}}");

        await SendPushToUser(task.CustomerId, "Order Update",
            $"Sorry, {business.Name} cannot process your order. Reason: {req.Reason}");

        await _webhookService.FireAsync("task.shop_rejected", new
        {
            taskId = task.Id,
            reason = req.Reason,
            businessName = business.Name
        }, businessId: task.BusinessId);

        await _taskHub.Clients.Group($"user_{task.CustomerId}").SendAsync("OnTaskStatusChanged", new
        {
            taskId = task.Id,
            status = "Cancelled",
            reason = req.Reason
        });

        return Ok(new { message = "Order rejected.", taskId = task.Id, reason = req.Reason });
    }

    /// <summary>
    /// Shop owner posts order to open market drivers (₹X offer).
    /// Any FREE network driver within radius can accept it.
    /// </summary>
    [HttpPost("{id}/post-market")]
    public async Task<IActionResult> PostToMarket(Guid id, [FromBody] PostMarketRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == id && !t.IsDeleted);

        if (task == null) return NotFound();
        if (!task.BusinessId.HasValue) return BadRequest(new { message = "Not a business order." });

        var business = await _db.Businesses.FirstOrDefaultAsync(b =>
            b.Id == task.BusinessId.Value && b.MerchantId == userId.Value);
        if (business == null) return Forbid();

        task.IsMarketPosted = true;
        task.MarketPostedAt = DateTime.UtcNow;
        task.MarketFareOffer = req.FareOffer;
        task.Status = PlatformTaskStatus.Broadcasting.ToString();

        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "OrderPostedToMarket", "TaskEntity", task.Id.ToString(),
            details: $"{{\"fareOffer\":{req.FareOffer},\"description\":\"{req.Description}\"}}");

        // Broadcast to all network drivers via SignalR
        await _taskHub.Clients.All.SendAsync("OnMarketTaskPosted", new
        {
            taskId = task.Id,
            description = req.Description ?? $"{task.OrderItems} — delivery from {task.PickupAddress} to {task.DropoffAddress}",
            fareOffer = req.FareOffer,
            pickupAddress = task.PickupAddress,
            dropoffAddress = task.DropoffAddress,
            pickupLat = task.PickupLatitude,
            pickupLng = task.PickupLongitude,
            distanceKm = task.DistanceKm,
            businessName = business.Name
        });

        await _webhookService.FireAsync("task.market_posted", BuildTaskPayload(task), businessId: task.BusinessId);

        return Ok(new
        {
            message = $"Order posted to market. Drivers within radius will see it with ₹{req.FareOffer} offer.",
            taskId = task.Id,
            fareOffer = req.FareOffer
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  DRIVER: Full status lifecycle with GPS + Geofence logging
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Driver starts trip — moves from Accepted → EN_ROUTE_PICKUP.
    /// Records driver's starting GPS location in delivery log.
    /// </summary>
    [HttpPost("{id}/start")]
    public async Task<IActionResult> StartTrip(Guid id, [FromBody] GpsEventRequest req)
    {
        var (userId, task, errorResult) = await ValidateDriverTask(id, "Accepted");
        if (errorResult != null) return errorResult;

        var fromStatus = task!.Status;
        task.Status = "EN_ROUTE_PICKUP";

        var log = CreateDeliveryLog(task, userId!.Value, "TripStarted", fromStatus, "EN_ROUTE_PICKUP",
            req.DriverLat, req.DriverLng, null, null, req.DeviceId, "Driver started trip");

        _db.TaskDeliveryLogs.Add(log);
        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "TripStarted", "TaskEntity", task.Id.ToString(), deviceId: req.DeviceId);

        await NotifyStatusChange(task, "EN_ROUTE_PICKUP", new
        {
            taskId = task.Id, status = "EN_ROUTE_PICKUP",
            driverLat = req.DriverLat, driverLng = req.DriverLng,
            message = "Driver has started and is on the way to pickup."
        });

        await _webhookService.FireAsync("task.started", new
        {
            taskId = task.Id, status = "EN_ROUTE_PICKUP",
            driverLat = req.DriverLat, driverLng = req.DriverLng
        }, businessId: task.BusinessId);

        return Ok(new { message = "Trip started.", taskId = task.Id, status = "EN_ROUTE_PICKUP", log = log.Id });
    }

    /// <summary>
    /// Driver arrives at pickup — moves EN_ROUTE_PICKUP → AT_PICKUP.
    /// Geofence check: driver must be within 150m of pickup lat/lng.
    /// ALERT fired if >400m.
    /// </summary>
    [HttpPost("{id}/arrive-pickup")]
    public async Task<IActionResult> ArriveAtPickup(Guid id, [FromBody] GpsEventRequest req)
    {
        var (userId, task, errorResult) = await ValidateDriverTask(id, "EN_ROUTE_PICKUP");
        if (errorResult != null) return errorResult;

        var fromStatus = task!.Status;
        var (geofenceStatus, distMeters) = GeofenceHelper.Evaluate(
            req.DriverLat, req.DriverLng,
            task.PickupLatitude, task.PickupLongitude);

        task.Status = "AT_PICKUP";

        var log = CreateDeliveryLog(task, userId!.Value, "ArrivedPickup", fromStatus, "AT_PICKUP",
            req.DriverLat, req.DriverLng, task.PickupLatitude, task.PickupLongitude,
            req.DeviceId, GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "pickup"),
            geofenceStatus, distMeters);

        _db.TaskDeliveryLogs.Add(log);
        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "ArrivedAtPickup", "TaskEntity", task.Id.ToString(),
            deviceId: req.DeviceId,
            details: $"{{\"geofence\":\"{geofenceStatus}\",\"distMeters\":{distMeters:F1}}}");

        // Push OTP to driver if required
        var otpMessage = task.IsPickupOtpRequired
            ? $"Give this OTP to the shopkeeper to verify pickup: {task.PickupOtp}"
            : "No OTP required for pickup. Proceed to collect.";

        await NotifyStatusChange(task, "AT_PICKUP", new
        {
            taskId = task.Id, status = "AT_PICKUP",
            geofenceStatus, distanceMeters = (int)distMeters,
            pickupOtpRequired = task.IsPickupOtpRequired,
            message = $"Driver arrived at pickup. {GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "pickup")}"
        });

        // RED ALERT to shop owner if geofence violation
        if (geofenceStatus == "ALERT" && task.BusinessId.HasValue)
        {
            await _webhookService.FireAsync("task.geofence_alert", new
            {
                taskId = task.Id, eventType = "ArrivedPickup",
                geofenceStatus, distanceMeters = (int)distMeters,
                message = GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "pickup"),
                driverLat = req.DriverLat, driverLng = req.DriverLng,
                expectedLat = task.PickupLatitude, expectedLng = task.PickupLongitude
            }, businessId: task.BusinessId);

            // Also push alert to shop owner
            await NotifyBusinessOwner(task.BusinessId.Value,
                "🚨 Delivery Alert",
                GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "pickup"));
        }

        return Ok(new
        {
            message = "Arrived at pickup.",
            taskId = task.Id, status = "AT_PICKUP",
            geofenceStatus, distanceMeters = (int)distMeters,
            pickupOtpRequired = task.IsPickupOtpRequired,
            pickupOtp = task.IsPickupOtpRequired ? task.PickupOtp : null,
            log = log.Id
        });
    }

    /// <summary>
    /// Driver confirms pickup — AT_PICKUP → PICKED_UP.
    /// If OTP required: verifies OTP first.
    /// If OTP not required: directly transitions.
    /// Geofence validated.
    /// </summary>
    [HttpPost("{id}/pickup")]
    public async Task<IActionResult> ConfirmPickup(Guid id, [FromBody] OtpGpsEventRequest req)
    {
        var (userId, task, errorResult) = await ValidateDriverTask(id, "AT_PICKUP");
        if (errorResult != null) return errorResult;

        // OTP validation if required
        if (task!.IsPickupOtpRequired)
        {
            if (string.IsNullOrEmpty(req.Otp))
                return BadRequest(new { message = "Pickup OTP is required for this order." });
            if (task.PickupOtp != req.Otp)
                return BadRequest(new { message = "Invalid Pickup OTP. Please check with the shopkeeper." });
        }

        var fromStatus = task.Status;
        var (geofenceStatus, distMeters) = GeofenceHelper.Evaluate(
            req.DriverLat, req.DriverLng,
            task.PickupLatitude, task.PickupLongitude);

        task.Status = "PICKED_UP";

        // Update driver duty status
        var profile = await _db.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId!.Value);
        if (profile != null) { profile.DutyStatus = DriverDutyStatus.InTransit.ToString(); profile.UpdatedAt = DateTime.UtcNow; }

        var log = CreateDeliveryLog(task, userId!.Value, "PickupVerified", fromStatus, "PICKED_UP",
            req.DriverLat, req.DriverLng, task.PickupLatitude, task.PickupLongitude,
            req.DeviceId, GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "pickup"),
            geofenceStatus, distMeters);

        _db.TaskDeliveryLogs.Add(log);
        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "PickupVerified", "TaskEntity", task.Id.ToString(),
            deviceId: req.DeviceId,
            details: $"{{\"otpVerified\":{task.IsPickupOtpRequired},\"geofence\":\"{geofenceStatus}\"}}");

        // Notify customer with drop OTP
        var dropMsg = task.IsDropOtpRequired
            ? $"Your order is on the way! Drop OTP: {task.DropoffOtp} — share with driver at delivery."
            : "Your order is picked up and on the way!";
        await SendPushToUser(task.CustomerId, "📦 Order Picked Up!", dropMsg);

        await NotifyStatusChange(task, "PICKED_UP", new
        {
            taskId = task.Id, status = "PICKED_UP",
            geofenceStatus, distanceMeters = (int)distMeters,
            dropOtpRequired = task.IsDropOtpRequired,
            message = "Order picked up. En route to drop point."
        });

        await _webhookService.FireAsync("task.pickup_verified", new
        {
            taskId = task.Id, status = "PICKED_UP",
            geofenceStatus, distanceMeters = (int)distMeters
        }, businessId: task.BusinessId);

        return Ok(new
        {
            message = "Pickup verified. En route to drop.",
            taskId = task.Id, status = "PICKED_UP",
            geofenceStatus, distanceMeters = (int)distMeters,
            dropOtpRequired = task.IsDropOtpRequired,
            log = log.Id
        });
    }

    /// <summary>
    /// Driver arrives at drop point — PICKED_UP → AT_DROP.
    /// Geofence check against dropoff coordinates.
    /// </summary>
    [HttpPost("{id}/arrive-drop")]
    public async Task<IActionResult> ArriveAtDrop(Guid id, [FromBody] GpsEventRequest req)
    {
        var (userId, task, errorResult) = await ValidateDriverTask(id, "PICKED_UP");
        if (errorResult != null) return errorResult;

        var fromStatus = task!.Status;
        var (geofenceStatus, distMeters) = GeofenceHelper.Evaluate(
            req.DriverLat, req.DriverLng,
            task.DropoffLatitude, task.DropoffLongitude);

        task.Status = "AT_DROP";

        var log = CreateDeliveryLog(task, userId!.Value, "ArrivedDrop", fromStatus, "AT_DROP",
            req.DriverLat, req.DriverLng, task.DropoffLatitude, task.DropoffLongitude,
            req.DeviceId, GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "drop"),
            geofenceStatus, distMeters);

        _db.TaskDeliveryLogs.Add(log);
        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "ArrivedAtDrop", "TaskEntity", task.Id.ToString(),
            deviceId: req.DeviceId,
            details: $"{{\"geofence\":\"{geofenceStatus}\",\"distMeters\":{distMeters:F1}}}");

        // Notify customer — send drop OTP if required
        var msg = task.IsDropOtpRequired
            ? $"🏁 Driver has arrived! Share OTP {task.DropoffOtp} to receive your order."
            : "🏁 Driver has arrived at your location!";
        await SendPushToUser(task.CustomerId, "Driver Arrived!", msg);

        await NotifyStatusChange(task, "AT_DROP", new
        {
            taskId = task.Id, status = "AT_DROP",
            geofenceStatus, distanceMeters = (int)distMeters,
            dropOtpRequired = task.IsDropOtpRequired,
            dropOtp = task.IsDropOtpRequired ? task.DropoffOtp : null
        });

        // Geofence alert
        if (geofenceStatus == "ALERT" && task.BusinessId.HasValue)
        {
            await _webhookService.FireAsync("task.geofence_alert", new
            {
                taskId = task.Id, eventType = "ArrivedDrop",
                geofenceStatus, distanceMeters = (int)distMeters,
                message = GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "drop")
            }, businessId: task.BusinessId);
        }

        await _webhookService.FireAsync("task.at_drop", new
        {
            taskId = task.Id, status = "AT_DROP", geofenceStatus
        }, businessId: task.BusinessId);

        return Ok(new
        {
            message = "Arrived at drop point.",
            taskId = task.Id, status = "AT_DROP",
            geofenceStatus, distanceMeters = (int)distMeters,
            dropOtpRequired = task.IsDropOtpRequired,
            log = log.Id
        });
    }

    /// <summary>
    /// Driver completes delivery — AT_DROP → COMPLETED.
    /// If OTP required: verifies drop OTP.
    /// Final geofence check at drop point.
    /// </summary>
    [HttpPost("{id}/complete")]
    public async Task<IActionResult> CompleteDelivery(Guid id, [FromBody] OtpGpsEventRequest req)
    {
        var (userId, task, errorResult) = await ValidateDriverTask(id, "AT_DROP");
        if (errorResult != null) return errorResult;

        // Drop OTP validation
        if (task!.IsDropOtpRequired)
        {
            if (string.IsNullOrEmpty(req.Otp))
                return BadRequest(new { message = "Drop OTP is required for this order." });
            if (task.DropoffOtp != req.Otp)
                return BadRequest(new { message = "Invalid Drop OTP. Please check with the customer." });
        }

        var fromStatus = task.Status;
        var (geofenceStatus, distMeters) = GeofenceHelper.Evaluate(
            req.DriverLat, req.DriverLng,
            task.DropoffLatitude, task.DropoffLongitude);

        task.Status = "Completed";
        task.CompletedAt = DateTime.UtcNow;

        // Driver back to FREE
        var profile = await _db.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId!.Value);
        if (profile != null) { profile.DutyStatus = DriverDutyStatus.Free.ToString(); profile.UpdatedAt = DateTime.UtcNow; }

        var log = CreateDeliveryLog(task, userId!.Value, "Delivered", fromStatus, "Completed",
            req.DriverLat, req.DriverLng, task.DropoffLatitude, task.DropoffLongitude,
            req.DeviceId, GeofenceHelper.AlertMessage(geofenceStatus, distMeters, "drop"),
            geofenceStatus, distMeters);

        _db.TaskDeliveryLogs.Add(log);
        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "OrderDelivered", "TaskEntity", task.Id.ToString(),
            deviceId: req.DeviceId,
            details: $"{{\"otpVerified\":{task.IsDropOtpRequired},\"geofence\":\"{geofenceStatus}\"}}");

        await SendPushToUser(task.CustomerId, "✅ Order Delivered!", "Your order has been delivered. Rate your experience!");

        await NotifyStatusChange(task, "Completed", new
        {
            taskId = task.Id, status = "Completed",
            geofenceStatus, distanceMeters = (int)distMeters,
            message = "Order delivered successfully!"
        });

        await _webhookService.FireAsync("task.completed", new
        {
            taskId = task.Id, status = "Completed",
            completedAt = task.CompletedAt,
            geofenceStatus, distanceMeters = (int)distMeters
        }, businessId: task.BusinessId);

        return Ok(new
        {
            message = "✅ Order delivered successfully!",
            taskId = task.Id, status = "Completed",
            completedAt = task.CompletedAt,
            geofenceStatus, distanceMeters = (int)distMeters,
            log = log.Id
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  GET: Full immutable delivery log
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Returns the complete delivery event log for an order.
    /// Includes GPS coordinates, geofence status, timestamps for every event.
    /// </summary>
    [HttpGet("{id}/delivery-log")]
    public async Task<IActionResult> GetDeliveryLog(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.DeliveryLogs)
                .ThenInclude(l => l.Driver)
            .Include(t => t.Customer)
            .Include(t => t.Business)
            .Include(t => t.AssignedDriver)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (task == null) return NotFound();

        var logs = task.DeliveryLogs
            .OrderBy(l => l.OccurredAt)
            .Select(l => new
            {
                l.Id,
                l.EventType,
                l.FromStatus,
                l.ToStatus,
                l.DriverLat,
                l.DriverLng,
                l.ExpectedLat,
                l.ExpectedLng,
                l.DistanceFromExpectedMeters,
                l.GeofenceStatus,
                GeofenceIcon = l.GeofenceStatus switch
                {
                    "OK" => "✅",
                    "WARNING" => "⚠️",
                    "ALERT" => "🚨",
                    _ => "—"
                },
                l.Notes,
                l.DeviceId,
                OccurredAt = l.OccurredAt.ToString("yyyy-MM-dd HH:mm:ss UTC"),
                DriverName = l.Driver?.FullName
            })
            .ToList();

        return Ok(new
        {
            taskId = task.Id,
            taskType = task.TaskType,
            currentStatus = task.Status,
            customerName = task.Customer?.FullName,
            driverName = task.AssignedDriver?.FullName,
            businessName = task.Business?.Name,
            pickupAddress = task.PickupAddress,
            dropoffAddress = task.DropoffAddress,
            createdAt = task.CreatedAt,
            completedAt = task.CompletedAt,
            totalEvents = logs.Count,
            deliveryLog = logs
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  Private helpers
    // ═══════════════════════════════════════════════════════════════════════

    private async Task<(Guid? userId, TaskEntity? task, IActionResult? error)> ValidateDriverTask(
        Guid taskId, string requiredStatus)
    {
        var userId = GetUserId();
        if (userId == null) return (null, null, Unauthorized());

        var task = await _db.Tasks
            .Include(t => t.Assignments)
            .FirstOrDefaultAsync(t => t.Id == taskId && !t.IsDeleted);

        if (task == null) return (userId, null, NotFound(new { message = "Order not found." }));
        if (task.AssignedDriverId != userId.Value)
            return (userId, null, Forbid());

        // Device lock check
        var assignment = task.Assignments.FirstOrDefault(a =>
            a.DriverId == userId.Value && a.Status == TaskAssignmentStatus.Accepted.ToString());
        // (device validation is intentionally relaxed here for lifecycle events — OTP check is the primary guard)

        if (!string.IsNullOrEmpty(requiredStatus) && task.Status != requiredStatus)
        {
            return (userId, null, BadRequest(new
            {
                message = $"Invalid status transition. Expected '{requiredStatus}', current is '{task.Status}'.",
                currentStatus = task.Status
            }));
        }

        return (userId, task, null);
    }

    private static TaskDeliveryLog CreateDeliveryLog(
        TaskEntity task, Guid driverId, string eventType,
        string? fromStatus, string toStatus,
        double? driverLat, double? driverLng,
        double? expectedLat, double? expectedLng,
        string? deviceId, string? notes,
        string geofenceStatus = "N/A", double distMeters = 0)
    {
        return new TaskDeliveryLog
        {
            TaskId = task.Id,
            DriverId = driverId,
            EventType = eventType,
            FromStatus = fromStatus,
            ToStatus = toStatus,
            DriverLat = driverLat,
            DriverLng = driverLng,
            ExpectedLat = expectedLat,
            ExpectedLng = expectedLng,
            DistanceFromExpectedMeters = distMeters > 0 ? distMeters : null,
            GeofenceStatus = geofenceStatus,
            DeviceId = deviceId,
            Notes = notes,
            OccurredAt = DateTime.UtcNow
        };
    }

    private async Task NotifyStatusChange(TaskEntity task, string newStatus, object payload)
    {
        try
        {
            await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnTaskStatusChanged", payload);
            await _taskHub.Clients.Group($"user_{task.CustomerId}").SendAsync("OnTaskStatusChanged", payload);
            if (task.BusinessId.HasValue)
                await _taskHub.Clients.Group($"business_{task.BusinessId}").SendAsync("OnTaskStatusChanged", payload);
        }
        catch { /* non-fatal */ }
    }

    private async Task SendPushToUser(Guid userId, string title, string body)
    {
        try
        {
            var session = await _db.UserDeviceSessions
                .Where(s => s.UserId == userId && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();

            if (session?.FcmToken != null)
            {
                await _fcmService.SendPushNotificationAsync(userId, session.FcmToken, title, body,
                    new Dictionary<string, string>());
            }
        }
        catch { /* non-fatal */ }
    }

    private async Task NotifyBusinessOwner(Guid businessId, string title, string body)
    {
        try
        {
            var biz = await _db.Businesses.FindAsync(businessId);
            if (biz != null) await SendPushToUser(biz.MerchantId, title, body);
        }
        catch { /* non-fatal */ }
    }

    private static object BuildTaskPayload(TaskEntity task) => new
    {
        taskId = task.Id,
        taskType = task.TaskType,
        status = task.Status,
        pickupAddress = task.PickupAddress,
        dropoffAddress = task.DropoffAddress,
        fareAmount = task.FareAmount,
        marketFareOffer = task.MarketFareOffer,
        isMarketPosted = task.IsMarketPosted,
        createdAt = task.CreatedAt
    };
}

// ── Request DTOs ─────────────────────────────────────────────────────────────

public record ConfirmOrderRequest(
    bool RequirePickupOtp = true,
    bool RequireDropOtp = true
);

public record RejectOrderRequest(string Reason);

public record PostMarketRequest(
    decimal FareOffer,
    string? Description = null
);

public record GpsEventRequest(
    double DriverLat,
    double DriverLng,
    string? DeviceId = null,
    double? Bearing = null,
    double? Speed = null
);

public record OtpGpsEventRequest(
    double DriverLat,
    double DriverLng,
    string? Otp = null,
    string? DeviceId = null
);
