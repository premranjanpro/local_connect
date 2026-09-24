using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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

    public TasksController(
        CoreDbContext dbContext,
        IDistanceMatrixService distanceMatrixService,
        IAuditService auditService)
    {
        _dbContext = dbContext;
        _distanceMatrixService = distanceMatrixService;
        _auditService = auditService;
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

        return Ok(new { message = "Task cancelled successfully." });
    }
}
