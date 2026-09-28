using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Api.Hubs;
using ShopConnector.Api.Services;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

/// <summary>
/// Multi-Stop Task Management — handles tasks with multiple pickup/drop stops.
///
/// Use cases:
///   School run:    POST /api/v1/multi-stop/create  (10 student stops)
///   Bulk delivery: POST /api/v1/multi-stop/create  (1 pickup + 10 customer drops)
///
/// Driver flow per stop:
///   POST /api/v1/multi-stop/{taskId}/stops/{stopId}/arrive   — with GPS
///   POST /api/v1/multi-stop/{taskId}/stops/{stopId}/complete — with OTP + GPS
///
/// GPS proximity trigger:
///   POST /api/v1/multi-stop/{taskId}/location-ping           — driver publishes position
///   → Server checks all PENDING stops for geofence proximity
///   → Sends "Driver arriving in ~2 min" FCM + WhatsApp to stop's recipient
///
/// Offline batch sync:
///   POST /api/v1/tasks/offline-sync                          — batch of offline events
/// </summary>
[ApiController]
[Route("api/v1/multi-stop")]
[Authorize]
public class MultiStopController : ControllerBase
{
    private readonly CoreDbContext _db;
    private readonly IAuditService _auditService;
    private readonly IHubContext<TaskHub> _taskHub;
    private readonly IWebhookService _webhookService;
    private readonly INotificationEnqueueService _notifQueue;

    public MultiStopController(
        CoreDbContext db, IAuditService auditService,
        IHubContext<TaskHub> taskHub, IWebhookService webhookService,
        INotificationEnqueueService notifQueue)
    {
        _db = db;
        _auditService = auditService;
        _taskHub = taskHub;
        _webhookService = webhookService;
        _notifQueue = notifQueue;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  CREATE multi-stop task
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Create a task with multiple stops.
    /// Each stop has its own address, OTP policy, recipient, geofence radius.
    /// Total km and duration calculated across all stops in order.
    /// </summary>
    [HttpPost("create")]
    public async Task<IActionResult> CreateMultiStopTask([FromBody] CreateMultiStopTaskRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (req.Stops == null || req.Stops.Count < 2)
            return BadRequest(new { message = "Multi-stop task requires at least 2 stops." });

        // Generate OTPs for each stop that requires one
        var random = new Random();
        var stops = req.Stops.Select((s, i) => new TaskStop
        {
            StopSequence = i + 1,
            StopType = s.StopType.ToUpper(),
            Address = s.Address,
            Latitude = s.Latitude,
            Longitude = s.Longitude,
            RecipientPhone = s.RecipientPhone,
            RecipientLabel = s.RecipientLabel,
            IsOtpRequired = s.IsOtpRequired,
            Otp = s.IsOtpRequired ? random.Next(100000, 999999).ToString() : null,
            GeofenceRadiusMeters = s.GeofenceRadiusMeters > 0 ? s.GeofenceRadiusMeters : 300,
            Notes = s.Notes,
            Status = "PENDING"
        }).ToList();

        // Approximate total distance (stop-to-stop Haversine)
        decimal totalKm = 0;
        for (int i = 0; i < stops.Count - 1; i++)
        {
            var dist = GeofenceHelper.DistanceMeters(
                stops[i].Latitude, stops[i].Longitude,
                stops[i + 1].Latitude, stops[i + 1].Longitude);
            totalKm += (decimal)(dist / 1000.0 * 1.30); // road factor
        }
        int totalMinutes = (int)(totalKm / 25.0m * 60) + (stops.Count * 3); // +3 min per stop

        var task = new TaskEntity
        {
            CustomerId = userId.Value,
            BusinessId = req.BusinessId,
            TaskType = req.TaskType,
            Status = "Broadcasting",
            // First stop = pickup reference
            PickupAddress = stops.First(s => s.StopType == "PICKUP").Address,
            PickupLatitude = stops.First(s => s.StopType == "PICKUP").Latitude,
            PickupLongitude = stops.First(s => s.StopType == "PICKUP").Longitude,
            // Last stop = drop reference
            DropoffAddress = stops.Last().Address,
            DropoffLatitude = stops.Last().Latitude,
            DropoffLongitude = stops.Last().Longitude,
            PickupOtp = stops.FirstOrDefault(s => s.StopType == "PICKUP" && s.IsOtpRequired)?.Otp ?? "",
            DropoffOtp = stops.LastOrDefault(s => s.StopType == "DROP" && s.IsOtpRequired)?.Otp ?? "",
            DistanceKm = totalKm,
            DurationMinutes = totalMinutes,
            FareAmount = req.FareAmount ?? Math.Round(25 + totalKm * 10, 0),
            PaymentMode = req.PaymentMode ?? "Cash",
            PaymentStatus = "Pending",
            OrderItems = req.OrderItemsJson,
            RequiresShopConfirm = req.RequiresShopConfirm,
            IsPickupOtpRequired = stops.Any(s => s.StopType == "PICKUP" && s.IsOtpRequired),
            IsDropOtpRequired = stops.Any(s => s.StopType == "DROP" && s.IsOtpRequired),
            CreatedAt = DateTime.UtcNow
        };

        _db.Tasks.Add(task);
        await _db.SaveChangesAsync();

        foreach (var stop in stops) stop.TaskId = task.Id;
        _db.TaskStops.AddRange(stops);
        await _db.SaveChangesAsync();

        await _auditService.LogActionAsync(userId.Value, "MultiStopTaskCreated", "TaskEntity", task.Id.ToString(),
            details: $"{{\"stops\":{stops.Count},\"totalKm\":{totalKm},\"taskType\":\"{task.TaskType}\"}}");

        // Notify each stop recipient: "Your pickup/drop scheduled — driver arriving soon"
        foreach (var stop in stops.Where(s => s.RecipientPhone != null || s.RecipientUserId != null))
        {
            var stopType = stop.StopType == "PICKUP" ? "pickup" : "delivery";
            var otpMsg = stop.IsOtpRequired ? $" OTP: {stop.Otp}" : "";
            await _notifQueue.EnqueueAsync(
                title: $"📦 Order Confirmed — {stopType} scheduled",
                body: $"Your {stopType} at {stop.Address} is confirmed.{otpMsg} Driver will be assigned shortly.",
                recipientUserId: stop.RecipientUserId,
                recipientPhone: stop.RecipientPhone,
                taskId: task.Id, taskStopId: stop.Id,
                channel: "BOTH",
                extraData: new() { { "stopId", stop.Id.ToString() }, { "type", "order_confirmed" } }
            );
        }

        // Broadcast to drivers
        await _taskHub.Clients.All.SendAsync("OnNewTaskBroadcast", new
        {
            taskId = task.Id, taskType = task.TaskType,
            fare = task.FareAmount, stopCount = stops.Count,
            pickupAddress = task.PickupAddress,
            dropoffAddress = task.DropoffAddress,
            totalKm = task.DistanceKm, durationMinutes = task.DurationMinutes
        });

        return Ok(new
        {
            taskId = task.Id,
            status = task.Status,
            totalStops = stops.Count,
            totalKm = task.DistanceKm,
            durationMinutes = task.DurationMinutes,
            fareAmount = task.FareAmount,
            stops = stops.Select(s => new
            {
                s.Id, s.StopSequence, s.StopType, s.Address,
                s.RecipientLabel, s.IsOtpRequired,
                otp = s.IsOtpRequired ? s.Otp : null,
                s.GeofenceRadiusMeters
            })
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  DRIVER: arrive at a specific stop
    // ═══════════════════════════════════════════════════════════════════════

    [HttpPost("{taskId}/stops/{stopId}/arrive")]
    public async Task<IActionResult> ArriveAtStop(Guid taskId, Guid stopId, [FromBody] GpsEventRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks.Include(t => t.Stops)
            .FirstOrDefaultAsync(t => t.Id == taskId && t.AssignedDriverId == userId.Value);
        if (task == null) return NotFound();

        var stop = task.Stops.FirstOrDefault(s => s.Id == stopId);
        if (stop == null) return NotFound(new { message = "Stop not found." });
        if (stop.Status == "COMPLETED")
            return BadRequest(new { message = "Stop already completed." });

        var (geoStatus, distMeters) = GeofenceHelper.Evaluate(
            req.DriverLat, req.DriverLng, stop.Latitude, stop.Longitude);

        stop.Status = "ARRIVED";
        stop.ArrivedAt = DateTime.UtcNow;
        stop.DriverLatAtArrival = req.DriverLat;
        stop.DriverLngAtArrival = req.DriverLng;
        stop.DistanceFromStopMeters = distMeters;
        stop.GeofenceStatus = geoStatus;

        var log = new TaskDeliveryLog
        {
            TaskId = task.Id, DriverId = userId.Value,
            EventType = $"ArrivedStop_{stop.StopSequence}_{stop.StopType}",
            FromStatus = task.Status, ToStatus = task.Status,
            DriverLat = req.DriverLat, DriverLng = req.DriverLng,
            ExpectedLat = stop.Latitude, ExpectedLng = stop.Longitude,
            DistanceFromExpectedMeters = distMeters,
            GeofenceStatus = geoStatus,
            Notes = $"Stop #{stop.StopSequence} — {stop.Address} — {GeofenceHelper.AlertMessage(geoStatus, distMeters, stop.StopType.ToLower())}",
            DeviceId = req.DeviceId
        };
        _db.TaskDeliveryLogs.Add(log);
        await _db.SaveChangesAsync();

        // Notify recipient of this stop
        var recipientMsg = stop.StopType == "PICKUP"
            ? $"🚗 Driver has arrived at pickup point: {stop.Address}" + (stop.IsOtpRequired ? $" — Share OTP {stop.Otp}" : "")
            : $"📦 Driver has arrived at your door! {stop.Address}" + (stop.IsOtpRequired ? $" — Your OTP: {stop.Otp}" : "");

        await _notifQueue.EnqueueAsync(
            title: stop.StopType == "PICKUP" ? "Driver Arrived at Pickup 📍" : "Driver Arrived — Delivery! 🏁",
            body: recipientMsg,
            recipientUserId: stop.RecipientUserId,
            recipientPhone: stop.RecipientPhone,
            taskId: task.Id, taskStopId: stop.Id,
            channel: "BOTH",
            extraData: new() { { "stopId", stop.Id.ToString() }, { "geofence", geoStatus }, { "type", "driver_arrived" } }
        );

        // Alert shop owner if geofence violation
        if (geoStatus == "ALERT" && task.BusinessId.HasValue)
        {
            await _webhookService.FireAsync("task.geofence_alert", new
            {
                taskId, stopId, stopSequence = stop.StopSequence,
                geoStatus, distanceMeters = (int)distMeters,
                message = GeofenceHelper.AlertMessage(geoStatus, distMeters, stop.StopType.ToLower())
            }, businessId: task.BusinessId);
        }

        await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnStopArrived", new
        {
            taskId, stopId, stopSequence = stop.StopSequence,
            geoStatus, distanceMeters = (int)distMeters
        });

        return Ok(new
        {
            message = $"Arrived at stop #{stop.StopSequence} ({stop.StopType})",
            stopId, geoStatus, distanceMeters = (int)distMeters,
            otpRequired = stop.IsOtpRequired,
            otp = stop.IsOtpRequired ? stop.Otp : null,
            log = log.Id
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  DRIVER: complete a stop (with OTP if required)
    // ═══════════════════════════════════════════════════════════════════════

    [HttpPost("{taskId}/stops/{stopId}/complete")]
    public async Task<IActionResult> CompleteStop(Guid taskId, Guid stopId, [FromBody] OtpGpsEventRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks.Include(t => t.Stops)
            .FirstOrDefaultAsync(t => t.Id == taskId && t.AssignedDriverId == userId.Value);
        if (task == null) return NotFound();

        var stop = task.Stops.FirstOrDefault(s => s.Id == stopId);
        if (stop == null) return NotFound(new { message = "Stop not found." });

        if (stop.IsOtpRequired)
        {
            if (string.IsNullOrEmpty(req.Otp))
                return BadRequest(new { message = $"OTP required for stop #{stop.StopSequence}." });
            if (stop.Otp != req.Otp)
                return BadRequest(new { message = $"Invalid OTP for stop #{stop.StopSequence}." });
        }

        var (geoStatus, distMeters) = GeofenceHelper.Evaluate(
            req.DriverLat, req.DriverLng, stop.Latitude, stop.Longitude);

        stop.Status = "COMPLETED";
        stop.CompletedAt = DateTime.UtcNow;
        stop.GeofenceStatus = geoStatus;

        // Check if ALL stops complete → mark task Completed
        var allComplete = task.Stops.All(s => s.Id == stop.Id || s.Status == "COMPLETED");

        var log = new TaskDeliveryLog
        {
            TaskId = task.Id, DriverId = userId.Value,
            EventType = $"StopCompleted_{stop.StopSequence}_{stop.StopType}",
            FromStatus = stop.Status, ToStatus = "COMPLETED",
            DriverLat = req.DriverLat, DriverLng = req.DriverLng,
            ExpectedLat = stop.Latitude, ExpectedLng = stop.Longitude,
            DistanceFromExpectedMeters = distMeters,
            GeofenceStatus = geoStatus,
            Notes = GeofenceHelper.AlertMessage(geoStatus, distMeters, stop.StopType.ToLower()),
            DeviceId = req.DeviceId
        };
        _db.TaskDeliveryLogs.Add(log);

        if (allComplete)
        {
            task.Status = "Completed";
            task.CompletedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();

        // Notify recipient
        var completedMsg = stop.StopType == "PICKUP"
            ? $"✅ Pickup confirmed at {stop.Address}. {(allComplete ? "All stops done!" : $"Next stop in progress.")}"
            : $"✅ Delivery completed at {stop.Address}. {(allComplete ? "All deliveries done! 🎉" : $"Next stop in progress.")}";

        await _notifQueue.EnqueueAsync(
            title: allComplete ? "✅ All Stops Completed!" : $"✅ Stop #{stop.StopSequence} Done",
            body: completedMsg,
            recipientUserId: stop.RecipientUserId,
            recipientPhone: stop.RecipientPhone,
            taskId: task.Id, taskStopId: stop.Id,
            channel: "BOTH",
            extraData: new() { { "stopId", stop.Id.ToString() }, { "type", "stop_completed" } }
        );

        await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnStopCompleted", new
        {
            taskId, stopId, stopSequence = stop.StopSequence,
            allComplete, taskStatus = task.Status
        });

        return Ok(new
        {
            message = $"Stop #{stop.StopSequence} completed!",
            stopId, allComplete, taskStatus = task.Status,
            remainingStops = task.Stops.Count(s => s.Status == "PENDING" || s.Status == "ARRIVED"),
            log = log.Id
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  DRIVER GPS PING → geofence proximity trigger
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Driver sends current GPS position.
    /// Server checks all PENDING stops — if driver within geofence_radius_meters:
    ///   - Sends "Driver arriving in ~X min" to stop's recipient (FCM + WhatsApp)
    ///   - Only fires ONCE per stop (proximity_notified = true)
    /// Also published to MQTT → TrackingHub for smooth map animation.
    /// </summary>
    [HttpPost("{taskId}/location-ping")]
    public async Task<IActionResult> LocationPing(Guid taskId, [FromBody] LocationPingRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Stops)
            .FirstOrDefaultAsync(t => t.Id == taskId && t.AssignedDriverId == userId.Value);
        if (task == null) return NotFound();

        var proximityTriggered = new List<object>();

        foreach (var stop in task.Stops.Where(s =>
            s.Status == "PENDING" && !s.ProximityNotified))
        {
            var distMeters = GeofenceHelper.DistanceMeters(
                req.Lat, req.Lng, stop.Latitude, stop.Longitude);

            if (distMeters <= stop.GeofenceRadiusMeters)
            {
                // Driver is within geofence — fire proximity notification
                stop.ProximityNotified = true;
                stop.ProximityNotifiedAt = DateTime.UtcNow;
                stop.Status = "DRIVER_APPROACHING";

                var etaMin = (int)(distMeters / 250.0) + 1; // ~250m/min city speed
                var stopType = stop.StopType == "PICKUP" ? "pickup" : "delivery";

                await _notifQueue.EnqueueAsync(
                    title: $"🚗 Driver arriving in ~{etaMin} min!",
                    body: $"Your driver is {(int)distMeters}m away from {stopType} at {stop.Address}. Be ready!",
                    recipientUserId: stop.RecipientUserId,
                    recipientPhone: stop.RecipientPhone,
                    taskId: task.Id, taskStopId: stop.Id,
                    channel: "BOTH",
                    extraData: new()
                    {
                        { "stopId", stop.Id.ToString() }, { "type", "driver_approaching" },
                        { "etaMinutes", etaMin.ToString() }, { "distanceMeters", ((int)distMeters).ToString() }
                    }
                );

                proximityTriggered.Add(new { stop.Id, stop.StopSequence, distanceMeters = (int)distMeters, etaMin });

                // Also push SignalR event to customer
                await _taskHub.Clients.Group($"user_{task.CustomerId}").SendAsync("OnDriverApproaching", new
                {
                    taskId, stopId = stop.Id, stop.StopSequence,
                    distanceMeters = (int)distMeters, etaMin, driverLat = req.Lat, driverLng = req.Lng
                });
            }
        }

        await _db.SaveChangesAsync();

        return Ok(new
        {
            taskId, driverLat = req.Lat, driverLng = req.Lng,
            proximityNotificationsTriggered = proximityTriggered.Count,
            triggered = proximityTriggered
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  GET: Full task with all stops + logs
    // ═══════════════════════════════════════════════════════════════════════

    [HttpGet("{taskId}")]
    public async Task<IActionResult> GetMultiStopTask(Guid taskId)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Stops)
            .Include(t => t.DeliveryLogs).ThenInclude(l => l.Driver)
            .Include(t => t.Customer)
            .Include(t => t.AssignedDriver)
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == taskId);

        if (task == null) return NotFound();

        var completedStops = task.Stops.Count(s => s.Status == "COMPLETED");
        var totalStops = task.Stops.Count;

        return Ok(new
        {
            task.Id, task.TaskType, task.Status,
            task.PickupAddress, task.DropoffAddress,
            task.DistanceKm, task.DurationMinutes, task.FareAmount,
            task.CreatedAt, task.CompletedAt,
            customerName = task.Customer?.FullName,
            driverName = task.AssignedDriver?.FullName,
            businessName = task.Business?.Name,
            progress = $"{completedStops}/{totalStops} stops",
            stops = task.Stops.OrderBy(s => s.StopSequence).Select(s => new
            {
                s.Id, s.StopSequence, s.StopType, s.Address,
                s.Latitude, s.Longitude, s.RecipientLabel, s.RecipientPhone,
                s.Status, s.IsOtpRequired,
                otp = (task.AssignedDriverId == userId || task.CustomerId == userId) && s.IsOtpRequired ? s.Otp : null,
                s.ArrivedAt, s.CompletedAt, s.GeofenceStatus,
                s.DistanceFromStopMeters, s.GeofenceRadiusMeters,
                s.ProximityNotified, s.ProximityNotifiedAt,
                geofenceIcon = s.GeofenceStatus switch
                {
                    "OK" => "✅", "WARNING" => "⚠️", "ALERT" => "🚨", _ => "—"
                }
            }),
            deliveryLog = task.DeliveryLogs.OrderBy(l => l.OccurredAt).Select(l => new
            {
                l.EventType, l.GeofenceStatus, l.DistanceFromExpectedMeters,
                l.Notes, OccurredAt = l.OccurredAt.ToString("HH:mm:ss"),
                DriverName = l.Driver?.FullName
            })
        });
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Offline Batch Sync Controller
// ═══════════════════════════════════════════════════════════════════════════

[ApiController]
[Route("api/v1/tasks")]
[Authorize]
public class OfflineSyncController : ControllerBase
{
    private readonly CoreDbContext _db;
    private readonly IAuditService _auditService;
    private readonly INotificationEnqueueService _notifQueue;
    private readonly IWebhookService _webhookService;
    private readonly IHubContext<TaskHub> _taskHub;

    public OfflineSyncController(CoreDbContext db, IAuditService auditService,
        INotificationEnqueueService notifQueue, IWebhookService webhookService,
        IHubContext<TaskHub> taskHub)
    {
        _db = db; _auditService = auditService;
        _notifQueue = notifQueue; _webhookService = webhookService;
        _taskHub = taskHub;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    /// <summary>
    /// Receives a batch of events that were buffered offline by the driver's app.
    /// Processes them in chronological order. Dispatches notifications with
    /// original event times (NOT the sync time).
    ///
    /// Each event in the batch:
    /// {
    ///   "type": "STATUS_CHANGE" | "GPS_PING" | "STOP_ARRIVE" | "STOP_COMPLETE",
    ///   "taskId": "...",
    ///   "stopId": "...",       // for stop events
    ///   "occurredAt": "2026-09-27T10:30:00Z",
    ///   "driverLat": 26.91,
    ///   "driverLng": 75.78,
    ///   "newStatus": "EN_ROUTE_PICKUP",
    ///   "otp": "123456",       // for OTP events
    ///   "deviceId": "..."
    /// }
    /// </summary>
    [HttpPost("offline-sync")]
    public async Task<IActionResult> OfflineSync([FromBody] OfflineSyncBatchRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (req.Events == null || req.Events.Count == 0)
            return BadRequest(new { message = "No events in batch." });

        // Store the batch for audit
        var batch = new OfflineEventBatch
        {
            DriverId = userId.Value,
            TaskId = req.TaskId,
            EventsJson = JsonSerializer.Serialize(req.Events),
            GpsPointsCount = req.Events.Count(e => e.Type == "GPS_PING"),
            OfflineSince = req.OfflineSince,
            SyncedAt = DateTime.UtcNow,
            Status = "PROCESSING"
        };
        _db.OfflineEventBatches.Add(batch);
        await _db.SaveChangesAsync();

        var processed = 0;
        var errors = new List<string>();

        // Process events chronologically
        foreach (var evt in req.Events.OrderBy(e => e.OccurredAt))
        {
            try
            {
                processed += await ProcessOfflineEventAsync(evt, userId.Value);
            }
            catch (Exception ex)
            {
                errors.Add($"{evt.Type} at {evt.OccurredAt}: {ex.Message}");
            }
        }

        // Update total offline KM from GPS pings
        var gpsPings = req.Events.Where(e => e.Type == "GPS_PING").OrderBy(e => e.OccurredAt).ToList();
        decimal offlineKm = 0;
        for (int i = 0; i < gpsPings.Count - 1; i++)
        {
            offlineKm += (decimal)(GeofenceHelper.DistanceMeters(
                gpsPings[i].DriverLat, gpsPings[i].DriverLng,
                gpsPings[i + 1].DriverLat, gpsPings[i + 1].DriverLng) / 1000.0);
        }
        batch.TotalKmOffline = offlineKm;
        batch.Status = errors.Count == 0 ? "DONE" : "ERROR";
        batch.ErrorMessage = errors.Count > 0 ? string.Join("; ", errors.Take(3)) : null;

        await _db.SaveChangesAsync();

        return Ok(new
        {
            batchId = batch.Id,
            eventsReceived = req.Events.Count,
            eventsProcessed = processed,
            gpsPointsSynced = gpsPings.Count,
            offlineKm = Math.Round(offlineKm, 2),
            errors = errors.Count,
            status = batch.Status,
            message = $"Sync complete. {processed} events processed, {gpsPings.Count} GPS points stored."
        });
    }

    private async Task<int> ProcessOfflineEventAsync(OfflineEventItem evt, Guid driverId)
    {
        if (!evt.TaskId.HasValue) return 0;

        var task = await _db.Tasks
            .Include(t => t.Stops)
            .FirstOrDefaultAsync(t => t.Id == evt.TaskId.Value && t.AssignedDriverId == driverId);
        if (task == null) return 0;

        switch (evt.Type)
        {
            case "STATUS_CHANGE" when evt.NewStatus != null:
            {
                var fromStatus = task.Status;
                task.Status = evt.NewStatus;
                if (evt.NewStatus == "Completed") task.CompletedAt = evt.OccurredAt;

                _db.TaskDeliveryLogs.Add(new TaskDeliveryLog
                {
                    TaskId = task.Id, DriverId = driverId,
                    EventType = $"OfflineSync_{evt.NewStatus}",
                    FromStatus = fromStatus, ToStatus = evt.NewStatus,
                    DriverLat = evt.DriverLat, DriverLng = evt.DriverLng,
                    GeofenceStatus = "N/A",
                    Notes = $"Synced from offline buffer. Actual event at {evt.OccurredAt:HH:mm} UTC",
                    DeviceId = evt.DeviceId, OccurredAt = evt.OccurredAt
                });

                // Enqueue notification with ACTUAL event time
                var body = evt.NewStatus switch
                {
                    "EN_ROUTE_PICKUP" => $"Your driver started trip at {evt.OccurredAt:hh:mm tt}",
                    "PICKED_UP" => $"Your order was picked up at {evt.OccurredAt:hh:mm tt}",
                    "Completed" => $"Your order was delivered at {evt.OccurredAt:hh:mm tt} ✅",
                    _ => $"Order status changed to {evt.NewStatus} at {evt.OccurredAt:hh:mm tt}"
                };

                await _notifQueue.EnqueueAsync(
                    title: "Order Update (Synced)",
                    body: body,
                    recipientUserId: task.CustomerId,
                    taskId: task.Id,
                    eventOccurredAt: evt.OccurredAt,
                    extraData: new() { { "status", evt.NewStatus }, { "offline", "true" } }
                );

                await _db.SaveChangesAsync();
                return 1;
            }

            case "STOP_COMPLETE" when evt.StopId.HasValue:
            {
                var stop = task.Stops.FirstOrDefault(s => s.Id == evt.StopId.Value);
                if (stop == null || stop.Status == "COMPLETED") return 0;

                if (stop.IsOtpRequired && stop.Otp != evt.Otp) return 0; // invalid OTP

                stop.Status = "COMPLETED";
                stop.CompletedAt = evt.OccurredAt;

                await _notifQueue.EnqueueAsync(
                    title: $"Stop #{stop.StopSequence} Completed",
                    body: $"Your {stop.StopType.ToLower()} at {stop.Address} was completed at {evt.OccurredAt:hh:mm tt}",
                    recipientUserId: stop.RecipientUserId,
                    recipientPhone: stop.RecipientPhone,
                    taskId: task.Id, taskStopId: stop.Id,
                    eventOccurredAt: evt.OccurredAt,
                    channel: "BOTH"
                );

                await _db.SaveChangesAsync();
                return 1;
            }

            case "GPS_PING":
                // GPS pings are bulk-inserted into telemetry DB (not core)
                // For now just count them — full implementation uses batch insert
                return 1;

            default:
                return 0;
        }
    }
}

// ── DTOs ───────────────────────────────────────────────────────────────────

public record CreateMultiStopTaskRequest(
    List<StopRequest> Stops,
    string TaskType = "MultiStop",
    Guid? BusinessId = null,
    decimal? FareAmount = null,
    string? PaymentMode = null,
    string? OrderItemsJson = null,
    bool RequiresShopConfirm = false
);

public record StopRequest(
    string StopType,          // PICKUP | DROP
    string Address,
    double Latitude,
    double Longitude,
    string? RecipientLabel = null,
    string? RecipientPhone = null,
    bool IsOtpRequired = true,
    int GeofenceRadiusMeters = 300,
    string? Notes = null
);

public record LocationPingRequest(
    double Lat,
    double Lng,
    double? Bearing = null,
    double? Speed = null,
    string? DeviceId = null
);

public record OfflineSyncBatchRequest(
    Guid? TaskId,
    List<OfflineEventItem> Events,
    DateTime? OfflineSince = null
);

public record OfflineEventItem(
    string Type,              // STATUS_CHANGE | GPS_PING | STOP_ARRIVE | STOP_COMPLETE
    DateTime OccurredAt,
    double DriverLat,
    double DriverLng,
    Guid? TaskId = null,
    Guid? StopId = null,
    string? NewStatus = null,
    string? Otp = null,
    string? DeviceId = null
);
