using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Api.Hubs;
using ShopConnector.Core.DTOs;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1/school-transit")]
[Authorize]
public class SchoolTransitController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IAuditService _auditService;
    private readonly IFcmNotificationService _fcmService;
    private readonly IHubContext<TaskHub> _taskHub;

    public SchoolTransitController(
        CoreDbContext dbContext,
        IAuditService auditService,
        IFcmNotificationService fcmService,
        IHubContext<TaskHub> taskHub)
    {
        _dbContext = dbContext;
        _auditService = auditService;
        _fcmService = fcmService;
        _taskHub = taskHub;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpPost("schedule")]
    public async Task<IActionResult> CreateSchedule([FromBody] CreateSchoolTransitScheduleRequest request)
    {
        var guardianId = GetUserId();
        if (guardianId == null) return Unauthorized();

        // 1. Create or find student user profile
        var student = new User
        {
            FullName = request.StudentName,
            Phone = !string.IsNullOrEmpty(request.StudentPhone) ? request.StudentPhone : $"STU-{Guid.NewGuid().ToString().Substring(0, 8)}",
            PinHash = BCrypt.Net.BCrypt.HashPassword("1234"),
            Role = "Customer",
            Status = "Active",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _dbContext.Users.Add(student);
        await _dbContext.SaveChangesAsync();

        // 2. Create SchoolTransitSchedule
        var schedule = new SchoolTransitSchedule
        {
            StudentId = student.Id,
            GuardianId = guardianId.Value,
            DriverId = request.DriverId,
            PickupTime = request.PickupTime,
            PickupLatitude = request.PickupLatitude,
            PickupLongitude = request.PickupLongitude,
            SchoolLatitude = request.SchoolLatitude,
            SchoolLongitude = request.SchoolLongitude,
            SchoolName = request.SchoolName,
            Status = "Active",
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.SchoolTransitSchedules.Add(schedule);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            guardianId.Value,
            "SchoolTransitScheduleCreated",
            "SchoolTransitSchedule",
            schedule.Id.ToString(),
            details: $"{{\"student\":\"{request.StudentName}\", \"school\":\"{request.SchoolName}\", \"pickupTime\":\"{request.PickupTime}\"}}"
        );

        return Ok(new
        {
            message = "School transit subscription scheduled successfully!",
            scheduleId = schedule.Id,
            studentName = request.StudentName,
            schoolName = request.SchoolName,
            pickupTime = request.PickupTime.ToString(@"hh\:mm")
        });
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMySchedules()
    {
        var guardianId = GetUserId();
        if (guardianId == null) return Unauthorized();

        var schedules = await _dbContext.SchoolTransitSchedules
            .Include(s => s.Student)
            .Include(s => s.Driver)
            .Where(s => s.GuardianId == guardianId.Value)
            .OrderByDescending(s => s.CreatedAt)
            .Select(s => new
            {
                s.Id,
                s.StudentId,
                StudentName = s.Student != null ? s.Student.FullName : "Student",
                s.SchoolName,
                PickupTime = s.PickupTime.ToString(@"hh\:mm"),
                s.PickupLatitude,
                s.PickupLongitude,
                s.SchoolLatitude,
                s.SchoolLongitude,
                s.Status,
                s.DriverId,
                DriverName = s.Driver != null ? s.Driver.FullName : "School Van Pool",
                DriverPhone = s.Driver != null ? s.Driver.Phone : "9829011223",
                VehicleType = s.Driver != null ? _dbContext.Vehicles.Where(v => v.DriverId == s.DriverId).Select(v => v.VehicleType).FirstOrDefault() ?? "School Van" : "School Van (Force Traveller)",
                PlateNumber = s.Driver != null ? _dbContext.Vehicles.Where(v => v.DriverId == s.DriverId).Select(v => v.PlateNumber).FirstOrDefault() ?? "RJ-14-SCH-1008" : "RJ-14-SCH-1008",
                s.CreatedAt
            })
            .ToListAsync();

        return Ok(schedules);
    }

    [HttpGet("driver/students")]
    public async Task<IActionResult> GetDriverStudents()
    {
        var driverId = GetUserId();
        if (driverId == null) return Unauthorized();

        var list = await _dbContext.SchoolTransitSchedules
            .Include(s => s.Student)
            .Include(s => s.Guardian)
            .Where(s => s.DriverId == driverId.Value || s.DriverId == null)
            .Take(30)
            .Select(s => new
            {
                s.Id,
                s.StudentId,
                StudentName = s.Student != null ? s.Student.FullName : "Student",
                GuardianName = s.Guardian != null ? s.Guardian.FullName : "Parent",
                GuardianPhone = s.Guardian != null ? s.Guardian.Phone : "",
                s.SchoolName,
                PickupTime = s.PickupTime.ToString(@"hh\:mm"),
                s.PickupLatitude,
                s.PickupLongitude,
                s.Status
            })
            .ToListAsync();

        return Ok(list);
    }

    [HttpPost("{id}/status")]
    public async Task<IActionResult> UpdateTransitStatus(Guid id, [FromBody] UpdateSchoolTransitStatusRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var schedule = await _dbContext.SchoolTransitSchedules
            .Include(s => s.Student)
            .Include(s => s.Guardian)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (schedule == null) return NotFound(new { message = "School transit schedule not found." });

        schedule.Status = request.Status;
        await _dbContext.SaveChangesAsync();

        string humanStatus = request.Status switch
        {
            "BoardedVan" => "safely boarded the school van",
            "AtSchool" => "reached school safely",
            "OnWayHome" => "boarded van for return journey home",
            "DroppedHome" => "safely arrived home",
            _ => request.Status
        };

        // Notify Guardian/Parent via FCM
        try
        {
            var parentSession = await _dbContext.UserDeviceSessions
                .Where(s => s.UserId == schedule.GuardianId && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();

            if (parentSession != null && !string.IsNullOrEmpty(parentSession.FcmToken))
            {
                await _fcmService.SendPushNotificationAsync(
                    schedule.GuardianId,
                    parentSession.FcmToken,
                    "School Transit Update",
                    $"{schedule.Student?.FullName ?? "Your child"} has {humanStatus}.",
                    new Dictionary<string, string>
                    {
                        { "type", "school_transit_update" },
                        { "status", request.Status },
                        { "scheduleId", schedule.Id.ToString() }
                    }
                );
            }

            await _taskHub.Clients.All.SendAsync("OnSchoolTransitStatusUpdated", new
            {
                scheduleId = schedule.Id,
                studentName = schedule.Student?.FullName,
                status = schedule.Status,
                message = $"{schedule.Student?.FullName} {humanStatus}"
            });
        }
        catch {}

        await _auditService.LogActionAsync(
            userId.Value,
            "SchoolTransitStatusChanged",
            "SchoolTransitSchedule",
            schedule.Id.ToString(),
            details: $"{{\"status\":\"{request.Status}\", \"notes\":\"{request.Notes}\"}}"
        );

        return Ok(new
        {
            message = $"Status updated to {request.Status}.",
            scheduleId = schedule.Id,
            status = schedule.Status
        });
    }

    [HttpPost("{id}/sos")]
    public async Task<IActionResult> TriggerSos(Guid id, [FromBody] SchoolTransitSosRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var schedule = await _dbContext.SchoolTransitSchedules
            .Include(s => s.Student)
            .Include(s => s.Guardian)
            .Include(s => s.Driver)
            .FirstOrDefaultAsync(s => s.Id == id);

        if (schedule == null) return NotFound();

        // Broadcast high priority alert
        await _taskHub.Clients.All.SendAsync("OnEmergencyAlert", new
        {
            scheduleId = schedule.Id,
            studentName = schedule.Student?.FullName,
            schoolName = schedule.SchoolName,
            alert = request.AlertMessage,
            latitude = request.Latitude ?? schedule.PickupLatitude,
            longitude = request.Longitude ?? schedule.PickupLongitude,
            timestamp = DateTime.UtcNow
        });

        return Ok(new { message = "EMERGENCY SOS broadcasted to guardian and control center." });
    }
}
