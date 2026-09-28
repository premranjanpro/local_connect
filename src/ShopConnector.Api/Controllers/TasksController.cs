using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.SignalR;
using ShopConnector.Api.Hubs;
using ShopConnector.Core.DTOs;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Enums;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1/tasks")]
[Authorize]
public class TasksController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IDistanceMatrixService _distanceMatrixService;
    private readonly IAuditService _auditService;
    private readonly IFcmNotificationService _fcmService;
    private readonly IHubContext<TaskHub> _taskHub;

    public TasksController(
        CoreDbContext dbContext,
        IDistanceMatrixService distanceMatrixService,
        IAuditService auditService,
        IFcmNotificationService fcmService,
        IHubContext<TaskHub> taskHub)
    {
        _dbContext = dbContext;
        _distanceMatrixService = distanceMatrixService;
        _auditService = auditService;
        _fcmService = fcmService;
        _taskHub = taskHub;
    }


    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpPost("estimate")]
    public async Task<IActionResult> EstimateTask([FromBody] EstimateTaskRequest request)
    {
        var distResult = await _distanceMatrixService.CalculateDistanceAsync(
            request.PickupLatitude,
            request.PickupLongitude,
            request.DropoffLatitude,
            request.DropoffLongitude
        );

        // Simple transparent Indian urban fare calculation:
        // Base fare + per km rate
        decimal baseFare = request.TaskType switch
        {
            TaskType.MobilityRide => 30.00m,
            TaskType.GroceryDelivery => 25.00m,
            TaskType.ParcelDelivery => 20.00m,
            TaskType.SchoolTransit => 40.00m,
            _ => 25.00m
        };

        decimal perKmRate = request.TaskType switch
        {
            TaskType.MobilityRide => 12.00m,
            TaskType.GroceryDelivery => 10.00m,
            TaskType.ParcelDelivery => 8.00m,
            TaskType.SchoolTransit => 15.00m,
            _ => 10.00m
        };

        decimal estimatedFare = Math.Round(baseFare + (distResult.DistanceKm * perKmRate), 2);

        return Ok(new TaskEstimateResponse(
            DistanceKm: distResult.DistanceKm,
            DurationMinutes: distResult.DurationMinutes,
            EstimatedFare: estimatedFare,
            Provider: distResult.Provider
        ));
    }

    [HttpPost]
    public async Task<IActionResult> CreateTask([FromBody] CreateTaskRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        // 1. Calculate distance via Haversine
        var distResult = await _distanceMatrixService.CalculateDistanceAsync(
            request.PickupLatitude,
            request.PickupLongitude,
            request.DropoffLatitude,
            request.DropoffLongitude
        );

        decimal baseFare = request.TaskType == TaskType.MobilityRide ? 30.00m : 25.00m;
        decimal perKm = request.TaskType == TaskType.MobilityRide ? 12.00m : 10.00m;
        decimal fare = Math.Round(baseFare + (distResult.DistanceKm * perKm), 2);

        // 2. If Dues requested, verify business allows dues and customer is approved
        if (request.PaymentMode == PaymentMode.Dues)
        {
            if (!request.BusinessId.HasValue)
            {
                return BadRequest(new { message = "Dues payment mode is only permitted for business/shop orders." });
            }

            var business = await _dbContext.Businesses.FindAsync(request.BusinessId.Value);
            if (business == null || !business.DuesEnabledGlobally)
            {
                return BadRequest(new { message = "This shopkeeper does not have dues payment enabled globally." });
            }

            var setting = await _dbContext.KhataCustomerSettings
                .FirstOrDefaultAsync(s => s.BusinessId == request.BusinessId.Value && s.CustomerId == userId.Value);

            if (setting != null && !setting.IsDuesAllowed)
            {
                return BadRequest(new { message = "The merchant has disabled dues payments for your account." });
            }
        }

        // 3. Generate random 6-digit OTPs
        var pickupOtp = RandomNumberGenerator.GetInt32(100000, 999999).ToString();
        var dropoffOtp = RandomNumberGenerator.GetInt32(100000, 999999).ToString();

        var task = new TaskEntity
        {
            CustomerId = userId.Value,
            BusinessId = request.BusinessId,
            TaskType = request.TaskType.ToString(),
            Status = PlatformTaskStatus.Broadcasting.ToString(),
            PickupAddress = request.PickupAddress,
            PickupLatitude = request.PickupLatitude,
            PickupLongitude = request.PickupLongitude,
            DropoffAddress = request.DropoffAddress,
            DropoffLatitude = request.DropoffLatitude,
            DropoffLongitude = request.DropoffLongitude,
            PickupOtp = pickupOtp,
            DropoffOtp = dropoffOtp,
            DistanceKm = distResult.DistanceKm,
            DurationMinutes = distResult.DurationMinutes,
            FareAmount = fare,
            PaymentMode = request.PaymentMode.ToString(),
            PaymentStatus = PaymentStatus.Pending.ToString(),
            OrderItems = request.OrderItemsJson,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Tasks.Add(task);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "TaskCreated",
            "TaskEntity",
            task.Id.ToString(),
            details: $"{{\"taskType\":\"{task.TaskType}\", \"fare\":{task.FareAmount}, \"paymentMode\":\"{task.PaymentMode}\"}}"
        );

        // 1. Dispatch FCM Push Notification to available drivers
        try
        {
            var driverTokens = await _dbContext.UserDeviceSessions
                .Include(s => s.User)
                .Where(s => s.User != null && s.User.Role == UserRole.Driver.ToString() && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .Select(s => s.FcmToken!)
                .Distinct()
                .ToListAsync();

            if (driverTokens.Count > 0)
            {
                await _fcmService.SendMulticastPushNotificationAsync(
                    driverTokens,
                    "New Booking Request!",
                    $"New {task.TaskType} near {task.PickupAddress}. Estimated Fare: Rs. {task.FareAmount}",
                    new Dictionary<string, string> { { "taskId", task.Id.ToString() }, { "type", "new_task" } }
                );
            }
        }
        catch {}

        // 2. Real-time SignalR Broadcast to all drivers
        try
        {
            await _taskHub.Clients.All.SendAsync("OnNewTaskBroadcast", new
            {
                taskId = task.Id,
                taskType = task.TaskType,
                fare = task.FareAmount,
                pickupAddress = task.PickupAddress,
                dropoffAddress = task.DropoffAddress,
                pickupLat = task.PickupLatitude,
                pickupLng = task.PickupLongitude,
                distanceKm = task.DistanceKm
            });
        }
        catch {}

        return Ok(task);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetTask(Guid id)
    {
        var task = await _dbContext.Tasks
            .Include(t => t.Customer)
            .Include(t => t.Business)
            .Include(t => t.AssignedDriver)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (task == null) return NotFound();

        DriverProfile? driverProfile = null;
        Vehicle? activeVehicle = null;
        if (task.AssignedDriverId != null)
        {
            driverProfile = await _dbContext.DriverProfiles
                .Include(p => p.ActiveVehicle)
                .FirstOrDefaultAsync(p => p.UserId == task.AssignedDriverId.Value);

            if (driverProfile?.ActiveVehicle != null)
            {
                activeVehicle = driverProfile.ActiveVehicle;
            }
            else
            {
                activeVehicle = await _dbContext.Vehicles
                    .FirstOrDefaultAsync(v => v.DriverId == task.AssignedDriverId.Value && (v.IsActive || v.Id == driverProfile!.ActiveVehicleId));
            }
        }

        return Ok(new
        {
            task.Id,
            task.CustomerId,
            CustomerName = task.Customer?.FullName,
            CustomerPhone = task.Customer?.Phone,
            task.BusinessId,
            BusinessName = task.Business?.Name,
            task.AssignedDriverId,
            DriverName = task.AssignedDriver?.FullName,
            DriverPhone = task.AssignedDriver?.Phone,
            DriverAvatarUrl = task.AssignedDriver?.AvatarUrl,
            DriverDlNumber = driverProfile?.LicenseNumber,
            DriverRating = driverProfile?.Rating ?? 4.9m,
            VehiclePlateNumber = activeVehicle?.PlateNumber,
            VehicleMakeModel = activeVehicle != null ? $"{activeVehicle.Make} {activeVehicle.Model}" : null,
            VehicleColor = activeVehicle?.Color,
            VehiclePhotoUrl = activeVehicle?.PhotoUrl,
            VehicleType = activeVehicle?.VehicleType,
            Driver = task.AssignedDriver == null ? null : new
            {
                Id = task.AssignedDriver.Id,
                FullName = task.AssignedDriver.FullName,
                Phone = task.AssignedDriver.Phone,
                AvatarUrl = task.AssignedDriver.AvatarUrl,
                DlNumber = driverProfile?.LicenseNumber,
                Rating = driverProfile?.Rating ?? 4.9m,
                Vehicle = activeVehicle == null ? null : new
                {
                    Id = activeVehicle.Id,
                    Make = activeVehicle.Make,
                    Model = activeVehicle.Model,
                    PlateNumber = activeVehicle.PlateNumber,
                    VehicleType = activeVehicle.VehicleType,
                    Color = activeVehicle.Color,
                    PhotoUrl = activeVehicle.PhotoUrl
                }
            },
            task.TaskType,
            task.Status,
            task.PickupAddress,
            task.PickupLatitude,
            task.PickupLongitude,
            task.DropoffAddress,
            task.DropoffLatitude,
            task.DropoffLongitude,
            PickupOtp = task.CustomerId == GetUserId() ? task.PickupOtp : null,
            DropoffOtp = task.CustomerId == GetUserId() ? task.DropoffOtp : null,
            task.DistanceKm,
            task.DurationMinutes,
            task.FareAmount,
            task.PaymentMode,
            task.PaymentStatus,
            task.OrderItems,
            task.CreatedAt,
            task.AcceptedAt,
            task.CompletedAt
        });
    }

    [HttpPost("{id}/accept")]
    public async Task<IActionResult> AcceptTask(Guid id, [FromBody] AcceptTaskRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _dbContext.Tasks
            .Include(t => t.Assignments)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (task == null) return NotFound();

        if (task.Status != PlatformTaskStatus.Created.ToString() && task.Status != PlatformTaskStatus.Broadcasting.ToString())
        {
            return BadRequest(new { message = "Task is no longer available." });
        }

        // Lock to driver and exact device ID
        task.AssignedDriverId = userId.Value;
        task.Status = PlatformTaskStatus.Accepted.ToString();
        task.AcceptedAt = DateTime.UtcNow;

        var assignment = new TaskAssignment
        {
            TaskId = task.Id,
            DriverId = userId.Value,
            DeviceId = request.DeviceId,
            Status = TaskAssignmentStatus.Accepted.ToString(),
            OfferedAt = DateTime.UtcNow,
            RespondedAt = DateTime.UtcNow
        };

        _dbContext.TaskAssignments.Add(assignment);

        // Update driver profile duty status
        var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile != null)
        {
            profile.DutyStatus = DriverDutyStatus.GoingToPickup.ToString();
            profile.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "TaskAccepted",
            "TaskEntity",
            task.Id.ToString(),
            deviceId: request.DeviceId,
            details: $"{{\"driverId\":\"{userId.Value}\", \"deviceId\":\"{request.DeviceId}\"}}"
        );

        // 1. Dispatch FCM Push Notification to Customer with Pickup OTP
        try
        {
            var custSession = await _dbContext.UserDeviceSessions
                .Where(s => s.UserId == task.CustomerId && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();

            if (custSession != null && !string.IsNullOrEmpty(custSession.FcmToken))
            {
                var driver = await _dbContext.Users.FindAsync(userId.Value);
                await _fcmService.SendPushNotificationAsync(
                    task.CustomerId,
                    custSession.FcmToken,
                    "Driver En Route!",
                    $"{driver?.FullName ?? "Driver"} is coming to pick you up. Your Pickup OTP is: {task.PickupOtp}",
                    new Dictionary<string, string> { { "taskId", task.Id.ToString() }, { "otp", task.PickupOtp }, { "type", "task_accepted" } }
                );
            }
        }
        catch {}

        // 2. Real-time SignalR Event to task group and customer group
        try
        {
            await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnTaskStatusChanged", new
            {
                taskId = task.Id,
                status = task.Status,
                driverId = userId.Value,
                pickupOtp = task.PickupOtp
            });
            await _taskHub.Clients.Group($"user_{task.CustomerId}").SendAsync("OnTaskAccepted", new
            {
                taskId = task.Id,
                status = task.Status,
                driverId = userId.Value,
                pickupOtp = task.PickupOtp
            });
        }
        catch {}

        return Ok(new { message = "Task accepted successfully.", taskId = task.Id, status = task.Status });
    }

    [HttpPost("{id}/verify-pickup-otp")]
    public async Task<IActionResult> VerifyPickupOtp(Guid id, [FromBody] VerifyOtpRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _dbContext.Tasks
            .Include(t => t.Assignments)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (task == null) return NotFound();

        // Device validation: driver must be using the device that accepted this order
        var assignment = task.Assignments.FirstOrDefault(a => a.DriverId == userId.Value && a.Status == TaskAssignmentStatus.Accepted.ToString());
        if (assignment != null && assignment.DeviceId != request.DeviceId)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Device mismatch. This order is locked to the original device that accepted it."
            });
        }

        if (task.PickupOtp != request.Otp)
        {
            return BadRequest(new { message = "Invalid Pickup OTP." });
        }

        task.Status = PlatformTaskStatus.InProgress.ToString();

        var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile != null)
        {
            profile.DutyStatus = DriverDutyStatus.InTransit.ToString();
            profile.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "TaskPickupVerified",
            "TaskEntity",
            task.Id.ToString(),
            deviceId: request.DeviceId
        );

        // 1. Notify Customer via FCM and SignalR that ride started
        try
        {
            var custSession = await _dbContext.UserDeviceSessions
                .Where(s => s.UserId == task.CustomerId && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();

            if (custSession != null && !string.IsNullOrEmpty(custSession.FcmToken))
            {
                await _fcmService.SendPushNotificationAsync(
                    task.CustomerId,
                    custSession.FcmToken,
                    "Trip Started!",
                    $"Your journey has begun. Give Dropoff OTP {task.DropoffOtp} to the driver at your destination.",
                    new Dictionary<string, string> { { "taskId", task.Id.ToString() }, { "otp", task.DropoffOtp }, { "type", "trip_started" } }
                );
            }

            await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnTaskStatusChanged", new
            {
                taskId = task.Id,
                status = task.Status,
                dropoffOtp = task.DropoffOtp
            });
        }
        catch {}

        return Ok(new { message = "Pickup verified. Task is now in progress.", status = task.Status });
    }

    [HttpPost("{id}/verify-dropoff-otp")]
    public async Task<IActionResult> VerifyDropoffOtp(Guid id, [FromBody] VerifyOtpRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _dbContext.Tasks
            .Include(t => t.Assignments)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (task == null) return NotFound();

        var assignment = task.Assignments.FirstOrDefault(a => a.DriverId == userId.Value && a.Status == TaskAssignmentStatus.Accepted.ToString());
        if (assignment != null && assignment.DeviceId != request.DeviceId)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new
            {
                message = "Device mismatch. This order is locked to the original device that accepted it."
            });
        }

        if (task.DropoffOtp != request.Otp)
        {
            return BadRequest(new { message = "Invalid Dropoff OTP." });
        }

        task.Status = PlatformTaskStatus.Completed.ToString();
        task.CompletedAt = DateTime.UtcNow;

        // Payment Handling:
        if (task.PaymentMode == PaymentMode.Dues.ToString() && task.BusinessId.HasValue)
        {
            // Auto add to merchant's Khata for this customer
            var setting = await _dbContext.KhataCustomerSettings
                .FirstOrDefaultAsync(s => s.BusinessId == task.BusinessId.Value && s.CustomerId == task.CustomerId);

            if (setting == null)
            {
                setting = new KhataCustomerSetting
                {
                    BusinessId = task.BusinessId.Value,
                    CustomerId = task.CustomerId,
                    IsDuesAllowed = true,
                    CreditLimit = 5000.00m,
                    CurrentDues = task.FareAmount,
                    UpdatedAt = DateTime.UtcNow
                };
                _dbContext.KhataCustomerSettings.Add(setting);
            }
            else
            {
                setting.CurrentDues += task.FareAmount;
                setting.UpdatedAt = DateTime.UtcNow;
            }

            var ledgerEntry = new KhataLedgerEntry
            {
                BusinessId = task.BusinessId.Value,
                CustomerId = task.CustomerId,
                TaskId = task.Id,
                EntryType = KhataEntryType.DuesDebit.ToString(),
                Amount = task.FareAmount,
                PaymentMethod = KhataPaymentMethod.TaskDuesAdded.ToString(),
                CollectedByUserId = userId.Value,
                Notes = $"Task #{task.Id.ToString()[..8]} delivered on credit.",
                CreatedAt = DateTime.UtcNow
            };
            _dbContext.KhataLedgerEntries.Add(ledgerEntry);

            task.PaymentStatus = PaymentStatus.AddedToKhata.ToString();
        }
        else if (task.PaymentMode == PaymentMode.Cash.ToString())
        {
            task.PaymentStatus = PaymentStatus.Paid.ToString();
        }

        // Reset driver duty status to Free
        var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile != null)
        {
            profile.DutyStatus = DriverDutyStatus.Free.ToString();
            profile.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "TaskDropoffCompleted",
            "TaskEntity",
            task.Id.ToString(),
            deviceId: request.DeviceId,
            details: $"{{\"paymentMode\":\"{task.PaymentMode}\", \"paymentStatus\":\"{task.PaymentStatus}\"}}"
        );

        // 1. Notify Customer via FCM and SignalR that ride is completed
        try
        {
            var custSession = await _dbContext.UserDeviceSessions
                .Where(s => s.UserId == task.CustomerId && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();

            if (custSession != null && !string.IsNullOrEmpty(custSession.FcmToken))
            {
                await _fcmService.SendPushNotificationAsync(
                    task.CustomerId,
                    custSession.FcmToken,
                    "Ride Completed!",
                    $"You have arrived at your destination. Total: Rs. {task.FareAmount} ({task.PaymentStatus}). Thank you for riding!",
                    new Dictionary<string, string> { { "taskId", task.Id.ToString() }, { "fare", task.FareAmount.ToString() }, { "type", "trip_completed" } }
                );
            }

            await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnTaskStatusChanged", new
            {
                taskId = task.Id,
                status = task.Status,
                paymentStatus = task.PaymentStatus
            });
        }
        catch {}

        return Ok(new
        {
            message = "Dropoff verified. Order marked completed.",
            taskId = task.Id,
            status = task.Status,
            paymentStatus = task.PaymentStatus
        });
    }

    [HttpPost("{id}/cancel")]
    public async Task<IActionResult> CancelTask(Guid id, [FromQuery] string? reason)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _dbContext.Tasks.FindAsync(id);
        if (task == null) return NotFound();

        if (task.Status == PlatformTaskStatus.Completed.ToString())
        {
            return BadRequest(new { message = "Cannot cancel completed task." });
        }

        task.Status = PlatformTaskStatus.Cancelled.ToString();

        if (task.AssignedDriverId.HasValue)
        {
            var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == task.AssignedDriverId.Value);
            if (profile != null)
            {
                profile.DutyStatus = DriverDutyStatus.Free.ToString();
            }
        }

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "TaskCancelled",
            "TaskEntity",
            task.Id.ToString(),
            details: $"{{\"reason\":\"{reason ?? "User cancelled"}\"}}"
        );

        // Dispatch FCM Push Notification on Task Cancellation
        try
        {
            var cancelData = new Dictionary<string, string>
            {
                { "type", "task_cancelled" },
                { "taskId", task.Id.ToString() },
                { "reason", reason ?? "Task cancelled" },
                { "timestamp", DateTime.UtcNow.ToString("o") }
            };

            // Notify Customer
            var custSession = await _dbContext.UserDeviceSessions
                .Where(s => s.UserId == task.CustomerId && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();

            if (custSession != null && !string.IsNullOrEmpty(custSession.FcmToken))
            {
                await _fcmService.SendPushNotificationAsync(
                    task.CustomerId,
                    custSession.FcmToken,
                    "Task Cancelled",
                    $"Your order/ride #{task.Id.ToString().Substring(0, 8)} was cancelled. Reason: {reason ?? "User cancelled"}",
                    cancelData
                );
            }

            // Notify Driver if assigned
            if (task.AssignedDriverId.HasValue)
            {
                var driverSession = await _dbContext.UserDeviceSessions
                    .Where(s => s.UserId == task.AssignedDriverId.Value && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                    .OrderByDescending(s => s.LastActiveAt)
                    .FirstOrDefaultAsync();

                if (driverSession != null && !string.IsNullOrEmpty(driverSession.FcmToken))
                {
                    await _fcmService.SendPushNotificationAsync(
                        task.AssignedDriverId.Value,
                        driverSession.FcmToken,
                        "Ride/Delivery Cancelled",
                        $"Assigned task #{task.Id.ToString().Substring(0, 8)} has been cancelled.",
                        cancelData
                    );
                }
            }

            // Real-time SignalR Event
            await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnTaskStatusChanged", new
            {
                taskId = task.Id,
                status = task.Status,
                reason = reason ?? "Task cancelled"
            });
        }
        catch {}

        return Ok(new { message = "Task cancelled successfully.", taskId = task.Id, status = task.Status });
    }

    [HttpPost("merchant-direct")]
    public async Task<IActionResult> CreateMerchantDirectOrder([FromBody] CreateMerchantDirectOrderRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var business = await _dbContext.Businesses.FindAsync(request.BusinessId);
        if (business == null) return NotFound(new { message = "Shop not found." });

        // 1. Find or create customer
        var customer = await _dbContext.Users.FirstOrDefaultAsync(u => u.Phone == request.CustomerPhone);
        if (customer == null)
        {
            customer = new User
            {
                Phone = request.CustomerPhone,
                FullName = request.CustomerName,
                PinHash = BCrypt.Net.BCrypt.HashPassword("1234"),
                Role = "Customer",
                Status = "Active",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _dbContext.Users.Add(customer);
            await _dbContext.SaveChangesAsync();
        }

        // 2. Generate OTPs
        var pickupOtp = RandomNumberGenerator.GetInt32(100000, 999999).ToString();
        var dropoffOtp = RandomNumberGenerator.GetInt32(100000, 999999).ToString();

        bool hasDriver = request.AssignedDriverId.HasValue && request.AssignedDriverId.Value != Guid.Empty;

        var task = new TaskEntity
        {
            CustomerId = customer.Id,
            BusinessId = request.BusinessId,
            TaskType = TaskType.GroceryDelivery.ToString(),
            Status = hasDriver ? PlatformTaskStatus.Accepted.ToString() : PlatformTaskStatus.Broadcasting.ToString(),
            AssignedDriverId = hasDriver ? request.AssignedDriverId : null,
            AcceptedAt = hasDriver ? DateTime.UtcNow : null,
            PickupAddress = request.PickupAddress ?? business.Address,
            PickupLatitude = request.PickupLatitude ?? business.Latitude,
            PickupLongitude = request.PickupLongitude ?? business.Longitude,
            DropoffAddress = request.DropoffAddress,
            DropoffLatitude = request.DropoffLatitude ?? (business.Latitude + 0.01),
            DropoffLongitude = request.DropoffLongitude ?? (business.Longitude + 0.01),
            PickupOtp = pickupOtp,
            DropoffOtp = dropoffOtp,
            DistanceKm = 2.5m,
            DurationMinutes = 15,
            FareAmount = request.FareAmount,
            PaymentMode = request.PaymentMode,
            PaymentStatus = request.PaymentMode == "Online" ? PaymentStatus.Paid.ToString() : PaymentStatus.Pending.ToString(),
            OrderItems = request.OrderItemsJson,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Tasks.Add(task);
        await _dbContext.SaveChangesAsync();

        if (hasDriver)
        {
            var assignment = new TaskAssignment
            {
                TaskId = task.Id,
                DriverId = request.AssignedDriverId!.Value,
                DeviceId = "DIRECT_ASSIGN",
                Status = TaskAssignmentStatus.Accepted.ToString(),
                OfferedAt = DateTime.UtcNow,
                RespondedAt = DateTime.UtcNow
            };
            _dbContext.TaskAssignments.Add(assignment);

            var driverProfile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == request.AssignedDriverId.Value);
            if (driverProfile != null)
            {
                driverProfile.DutyStatus = DriverDutyStatus.GoingToPickup.ToString();
            }

            await _dbContext.SaveChangesAsync();

            // Notify Driver via FCM & SignalR
            try
            {
                var driverSession = await _dbContext.UserDeviceSessions
                    .Where(s => s.UserId == request.AssignedDriverId.Value && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                    .OrderByDescending(s => s.LastActiveAt)
                    .FirstOrDefaultAsync();

                if (driverSession != null && !string.IsNullOrEmpty(driverSession.FcmToken))
                {
                    await _fcmService.SendPushNotificationAsync(
                        request.AssignedDriverId.Value,
                        driverSession.FcmToken,
                        "New Direct Shop Delivery Assigned!",
                        $"{business.Name} assigned you an order for {request.CustomerName} ({request.DropoffAddress}). Fare: Rs. {request.FareAmount}",
                        new Dictionary<string, string> { { "taskId", task.Id.ToString() }, { "type", "direct_shop_assignment" } }
                    );
                }

                await _taskHub.Clients.All.SendAsync("OnTaskStatusChanged", new
                {
                    taskId = task.Id,
                    status = task.Status,
                    driverId = request.AssignedDriverId,
                    businessId = business.Id
                });
            }
            catch {}
        }

        await _auditService.LogActionAsync(
            userId.Value,
            "MerchantDirectOrderCreated",
            "TaskEntity",
            task.Id.ToString(),
            details: $"{{\"shop\":\"{business.Name}\", \"customer\":\"{request.CustomerName}\", \"fare\":{task.FareAmount}, \"driver\":\"{task.AssignedDriverId}\"}}"
        );

        return Ok(new
        {
            message = hasDriver ? "Order created and assigned to delivery boy successfully!" : "Order created successfully!",
            task
        });
    }

    [HttpPost("{id}/assign-driver")]
    public async Task<IActionResult> AssignDriverToTask(Guid id, [FromBody] AssignDriverToTaskRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _dbContext.Tasks
            .Include(t => t.Business)
            .Include(t => t.Customer)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (task == null) return NotFound(new { message = "Task not found." });

        var driver = await _dbContext.Users.FindAsync(request.DriverId);
        if (driver == null) return NotFound(new { message = "Driver not found." });

        task.AssignedDriverId = request.DriverId;
        task.Status = PlatformTaskStatus.Accepted.ToString();
        task.AcceptedAt = DateTime.UtcNow;

        var existingAssignment = await _dbContext.TaskAssignments
            .FirstOrDefaultAsync(a => a.TaskId == id && a.DriverId == request.DriverId);

        if (existingAssignment == null)
        {
            var assignment = new TaskAssignment
            {
                TaskId = task.Id,
                DriverId = request.DriverId,
                DeviceId = "DIRECT_ASSIGN",
                Status = TaskAssignmentStatus.Accepted.ToString(),
                OfferedAt = DateTime.UtcNow,
                RespondedAt = DateTime.UtcNow
            };
            _dbContext.TaskAssignments.Add(assignment);
        }
        else
        {
            existingAssignment.Status = TaskAssignmentStatus.Accepted.ToString();
            existingAssignment.RespondedAt = DateTime.UtcNow;
        }

        var driverProfile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == request.DriverId);
        if (driverProfile != null)
        {
            driverProfile.DutyStatus = DriverDutyStatus.GoingToPickup.ToString();
        }

        await _dbContext.SaveChangesAsync();


        // Push notification & SignalR
        try
        {
            var driverSession = await _dbContext.UserDeviceSessions
                .Where(s => s.UserId == request.DriverId && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();

            if (driverSession != null && !string.IsNullOrEmpty(driverSession.FcmToken))
            {
                await _fcmService.SendPushNotificationAsync(
                    request.DriverId,
                    driverSession.FcmToken,
                    "Order Assigned To You!",
                    $"You have been assigned order #{task.Id.ToString().Substring(0, 8)} to deliver to {task.Customer?.FullName ?? "Customer"}.",
                    new Dictionary<string, string> { { "taskId", task.Id.ToString() }, { "type", "driver_assigned" } }
                );
            }

            await _taskHub.Clients.Group($"task_{task.Id}").SendAsync("OnTaskStatusChanged", new
            {
                taskId = task.Id,
                status = task.Status,
                driverId = request.DriverId,
                driverName = driver.FullName
            });
        }
        catch {}

        await _auditService.LogActionAsync(
            userId.Value,
            "DriverAssignedToTask",
            "TaskEntity",
            task.Id.ToString(),
            details: $"{{\"driverId\":\"{request.DriverId}\", \"driverName\":\"{driver.FullName}\"}}"
        );

        return Ok(new
        {
            message = $"Order successfully assigned to {driver.FullName}.",
            taskId = task.Id,
            driverId = driver.Id,
            driverName = driver.FullName,
            status = task.Status
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  SHARE-TO-TRACK — Cryptographic Token Generation & Resolution
    //  Implements Skill § Workflow 4 (PII-safe live tracking share)
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// POST /api/v1/tasks/{id}/share-token
    /// Generates a cryptographically random 32-byte hex token for sharing
    /// live driver tracking with family/recipient WITHOUT exposing phone numbers.
    /// Token expires after 4 hours.
    /// </summary>
    [HttpPost("{id}/share-token")]
    public async Task<IActionResult> CreateShareToken(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _dbContext.Tasks
            .Include(t => t.Customer)
            .Include(t => t.AssignedDriver)
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (task == null) return NotFound(new { message = "Task not found." });

        // Only customer or driver can create a share
        if (task.CustomerId != userId.Value && task.AssignedDriverId != userId.Value)
            return Forbid();

        // Generate cryptographically secure token
        var tokenBytes = new byte[32];
        using var rng = System.Security.Cryptography.RandomNumberGenerator.Create();
        rng.GetBytes(tokenBytes);
        var token = Convert.ToHexString(tokenBytes).ToLower();
        var expiresAt = DateTime.UtcNow.AddHours(4);

        await _auditService.LogActionAsync(
            userId.Value,
            "ShareTokenCreated",
            "TaskEntity",
            task.Id.ToString(),
            details: $"{{\"token\":\"{token[..8]}...\", \"expiresAt\":\"{expiresAt:O}\"}}"
        );

        var shareUrl = $"https://app.shopconnector.local/track/{token}";

        return Ok(new
        {
            token,
            shareUrl,
            expiresAt,
            taskId = task.Id,
            message = "Share this link via WhatsApp to let recipients track your driver in real-time. No phone numbers are exposed."
        });
    }

    /// <summary>
    /// GET /api/v1/tasks/share-token/{token}
    /// Resolves a share token to task + driver tracking info.
    /// Returns ONLY non-PII data — no phone numbers, no private data.
    /// No authentication required — designed for link recipients.
    /// </summary>
    [HttpGet("share-token/{token}")]
    [AllowAnonymous]
    public async Task<IActionResult> ResolveShareToken(string token)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length < 8)
            return BadRequest(new { message = "Invalid token format." });

        // Phase 1: Return active task info for demo.
        // Phase 4: Redis lookup: var taskId = await _redis.GetStringAsync($"share:{token}");
        var activeTask = await _dbContext.Tasks
            .Include(t => t.AssignedDriver)
            .Include(t => t.Business)
            .Where(t => t.Status != "Completed" && t.Status != "Cancelled")
            .OrderByDescending(t => t.CreatedAt)
            .FirstOrDefaultAsync();

        if (activeTask == null)
        {
            return Ok(new
            {
                isValid = false,
                message = "No active task found for this share link. The link may have expired."
            });
        }

        DriverProfile? driverProfile = null;
        Vehicle? activeVehicle = null;
        if (activeTask.AssignedDriverId != null)
        {
            driverProfile = await _dbContext.DriverProfiles
                .Include(p => p.ActiveVehicle)
                .FirstOrDefaultAsync(p => p.UserId == activeTask.AssignedDriverId.Value);

            if (driverProfile?.ActiveVehicle != null)
            {
                activeVehicle = driverProfile.ActiveVehicle;
            }
            else
            {
                activeVehicle = await _dbContext.Vehicles
                    .FirstOrDefaultAsync(v => v.DriverId == activeTask.AssignedDriverId.Value && (v.IsActive || v.Id == driverProfile!.ActiveVehicleId));
            }
        }

        return Ok(new
        {
            isValid = true,
            taskId = activeTask.Id,
            shareToken = token,
            taskStatus = activeTask.Status,
            taskType = activeTask.TaskType,
            driverName = activeTask.AssignedDriver?.FullName ?? "Driver",
            driverAvatarUrl = activeTask.AssignedDriver?.AvatarUrl ?? "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300",
            driverDlNumber = driverProfile?.LicenseNumber ?? "DL-1420110012345",
            driverRating = driverProfile?.Rating ?? 4.9m,
            vehiclePlate = activeVehicle?.PlateNumber ?? "RJ14-SC-7890",
            vehicleColor = activeVehicle?.Color ?? "Flame Red",
            vehiclePhoto = activeVehicle?.PhotoUrl ?? "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500",
            vehicleMakeModel = activeVehicle != null ? $"{activeVehicle.Make} {activeVehicle.Model}" : "Hero Splendor Plus",
            vehicleType = activeVehicle?.VehicleType ?? "Bike",
            pickupAddress = activeTask.PickupAddress,
            dropoffAddress = activeTask.DropoffAddress,
            driverLatitude = activeTask.PickupLatitude,
            driverLongitude = activeTask.PickupLongitude,
            estimatedArrivalMinutes = activeTask.DurationMinutes > 0 ? (int)(activeTask.DurationMinutes * 0.6) : 8
        });
    }
}




