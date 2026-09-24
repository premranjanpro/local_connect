using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.DTOs;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Enums;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1")]
[Authorize]
public class AuditAndTelemetryController : ControllerBase
{
    private readonly CoreDbContext _coreDb;
    private readonly TelemetryDbContext _telemetryDb;

    public AuditAndTelemetryController(CoreDbContext coreDb, TelemetryDbContext telemetryDb)
    {
        _coreDb = coreDb;
        _telemetryDb = telemetryDb;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    // --- Telemetry Endpoints ---

    [HttpPost("telemetry/ping")]
    public async Task<IActionResult> RecordGpsPing([FromBody] DriverGpsPingRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        // 1. Single-device order enforcement check:
        // If driver has an active assigned task, verify device_id
        var activeTask = await _coreDb.Tasks
            .Include(t => t.Assignments)
            .Where(t => t.AssignedDriverId == userId.Value &&
                        (t.Status == PlatformTaskStatus.Accepted.ToString() ||
                         t.Status == PlatformTaskStatus.EnRoutePickup.ToString() ||
                         t.Status == PlatformTaskStatus.ArrivedPickup.ToString() ||
                         t.Status == PlatformTaskStatus.InProgress.ToString()))
            .FirstOrDefaultAsync();

        if (activeTask != null)
        {
            var assignment = activeTask.Assignments
                .FirstOrDefault(a => a.DriverId == userId.Value && a.Status == TaskAssignmentStatus.Accepted.ToString());

            if (assignment != null && assignment.DeviceId != request.DeviceId)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    message = "Telemetry rejected: GPS updates are restricted to the device currently executing the active order."
                });
            }
        }

        // 2. Insert high-frequency telemetry ping
        var ping = new DriverGpsPing
        {
            DriverId = userId.Value,
            DeviceId = request.DeviceId,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Altitude = request.Altitude,
            Heading = request.Heading,
            Speed = request.Speed,
            Accuracy = request.Accuracy,
            BatteryPct = request.BatteryPct,
            IsCharging = request.IsCharging,
            Timestamp = DateTime.UtcNow
        };
        _telemetryDb.DriverGpsPings.Add(ping);

        // 3. Upsert current driver location for instant query without scanning ping history
        var currentLoc = await _telemetryDb.DriverLocationCurrent.FindAsync(userId.Value);
        if (currentLoc == null)
        {
            currentLoc = new DriverLocationCurrent
            {
                DriverId = userId.Value,
                DeviceId = request.DeviceId,
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                Heading = request.Heading,
                Speed = request.Speed,
                DutyStatus = "Active",
                UpdatedAt = DateTime.UtcNow
            };
            _telemetryDb.DriverLocationCurrent.Add(currentLoc);
        }
        else
        {
            currentLoc.DeviceId = request.DeviceId;
            currentLoc.Latitude = request.Latitude;
            currentLoc.Longitude = request.Longitude;
            currentLoc.Heading = request.Heading;
            currentLoc.Speed = request.Speed;
            currentLoc.UpdatedAt = DateTime.UtcNow;
        }

        // 4. Update DriverProfile in Core DB with latest coordinates
        var profile = await _coreDb.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile != null)
        {
            profile.CurrentLatitude = request.Latitude;
            profile.CurrentLongitude = request.Longitude;
            profile.CurrentHeading = request.Heading;
            profile.CurrentSpeed = request.Speed;
            profile.BatteryPct = request.BatteryPct;
            profile.IsCharging = request.IsCharging;
            profile.LastHeartbeatAt = DateTime.UtcNow;
        }

        await _telemetryDb.SaveChangesAsync();
        await _coreDb.SaveChangesAsync();

        return Ok(new { success = true, timestamp = ping.Timestamp });
    }

    [AllowAnonymous]
    [HttpGet("telemetry/driver/{driverId}/current")]
    public async Task<IActionResult> GetDriverCurrentLocation(Guid driverId)
    {
        var loc = await _telemetryDb.DriverLocationCurrent.FindAsync(driverId);
        if (loc == null) return NotFound(new { message = "Driver location not available." });

        return Ok(new
        {
            loc.DriverId,
            loc.Latitude,
            loc.Longitude,
            loc.Heading,
            loc.Speed,
            loc.UpdatedAt
        });
    }

    // --- Audit Logs Endpoints ---

    [HttpGet("audit/logs")]
    public async Task<IActionResult> GetAuditLogs(
        [FromQuery] string? action,
        [FromQuery] string? entityType,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var query = _coreDb.AuditActionLogs.Include(a => a.User).AsQueryable();

        if (!string.IsNullOrEmpty(action))
            query = query.Where(a => EF.Functions.ILike(a.Action, $"%{action}%"));

        if (!string.IsNullOrEmpty(entityType))
            query = query.Where(a => EF.Functions.ILike(a.EntityType, $"%{entityType}%"));

        var total = await query.CountAsync();
        var logs = await query
            .OrderByDescending(a => a.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(a => new
            {
                a.Id,
                a.UserId,
                UserName = a.User != null ? a.User.FullName : null,
                UserRole = a.User != null ? a.User.Role : null,
                a.Action,
                a.EntityType,
                a.EntityId,
                a.IpAddress,
                a.DeviceId,
                a.Details,
                a.CreatedAt
            })
            .ToListAsync();

        return Ok(new { Total = total, Page = page, PageSize = pageSize, Logs = logs });
    }

    [HttpGet("audit/messages")]
    public async Task<IActionResult> GetMessageLogs(
        [FromQuery] string? channel,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var query = _coreDb.MessageDispatchLogs.Include(m => m.RecipientUser).AsQueryable();

        if (!string.IsNullOrEmpty(channel))
            query = query.Where(m => m.Channel == channel);

        var total = await query.CountAsync();
        var logs = await query
            .OrderByDescending(m => m.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(m => new
            {
                m.Id,
                m.RecipientUserId,
                RecipientName = m.RecipientUser != null ? m.RecipientUser.FullName : null,
                m.Channel,
                m.RecipientAddress,
                m.SubjectOrTitle,
                m.Body,
                m.Status,
                m.ErrorMessage,
                m.CreatedAt
            })
            .ToListAsync();

        return Ok(new { Total = total, Page = page, PageSize = pageSize, Messages = logs });
    }
}
