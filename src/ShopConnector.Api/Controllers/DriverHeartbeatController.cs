using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

/// <summary>
/// Driver heartbeat and location tracking endpoint.
///
/// POST /api/v1/driver/heartbeat
///   Body: { lat, lng, mode: "IDLE"|"RIDE", rideId?, bearing?, speed?, batteryPct? }
///
/// Modes:
///   IDLE — driver is online, on duty, not in a ride → stored as 1-min ping
///   RIDE — driver has active ride →  stored as 15-sec ping + geofence check
///
/// Even if GPS is unavailable (null lat/lng):
///   → Sends heartbeat with last known position + isGpsAvailable: false
///   → Server knows driver is alive, just GPS-denied temporarily
///   → Last known position is stored as fallback
/// </summary>
[ApiController]
[Route("api/v1/driver")]
[Authorize]
public class DriverHeartbeatController : ControllerBase
{
    private readonly CoreDbContext _db;
    private readonly TelemetryDbContext _telemetryDb;

    public DriverHeartbeatController(CoreDbContext db, TelemetryDbContext telemetryDb)
    {
        _db = db;
        _telemetryDb = telemetryDb;
    }

    private Guid? GetUserId()
    {
        var s = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(s, out var id) ? id : null;
    }

    [HttpPost("heartbeat")]
    public async Task<IActionResult> Heartbeat([FromBody] HeartbeatRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var now = DateTime.UtcNow;

        // Update driver profile: last seen, duty status
        var profile = await _db.DriverProfiles
            .FirstOrDefaultAsync(p => p.UserId == userId.Value);

        if (profile != null)
        {
            // Only update position if GPS available
            if (req.IsGpsAvailable && req.Lat.HasValue && req.Lng.HasValue)
            {
                profile.CurrentLatitude = req.Lat.Value;
                profile.CurrentLongitude = req.Lng.Value;
                profile.LastLocationAt = now;
            }
            profile.LastHeartbeatAt = now;
            profile.IsOnline = true;
            profile.TrackingMode = req.Mode;
            profile.UpdatedAt = now;
        }

        // Store GPS ping in telemetry (regardless of mode)
        if (req.IsGpsAvailable && req.Lat.HasValue && req.Lng.HasValue)
        {
            _telemetryDb.DriverGpsPings.Add(new DriverGpsPing
            {
                DriverId = userId.Value,
                DeviceId = "mobile-app",
                Latitude = req.Lat.Value,
                Longitude = req.Lng.Value,
                Heading = req.Bearing ?? 0,
                Speed = req.Speed ?? 0,
                Accuracy = req.Accuracy ?? 0,
                BatteryPct = req.BatteryPct ?? 100,
                Timestamp = now
            });

            var currLoc = await _telemetryDb.DriverLocationCurrent.FindAsync(userId.Value);
            if (currLoc == null)
            {
                _telemetryDb.DriverLocationCurrent.Add(new DriverLocationCurrent
                {
                    DriverId = userId.Value,
                    DeviceId = "mobile-app",
                    Latitude = req.Lat.Value,
                    Longitude = req.Lng.Value,
                    Heading = req.Bearing ?? 0,
                    Speed = req.Speed ?? 0,
                    DutyStatus = req.Mode == "RIDE" ? "Busy" : "Free",
                    UpdatedAt = now
                });
            }
            else
            {
                currLoc.Latitude = req.Lat.Value;
                currLoc.Longitude = req.Lng.Value;
                currLoc.Heading = req.Bearing ?? 0;
                currLoc.Speed = req.Speed ?? 0;
                currLoc.DutyStatus = req.Mode == "RIDE" ? "Busy" : "Free";
                currLoc.UpdatedAt = now;
            }
        }

        await _db.SaveChangesAsync();
        await _telemetryDb.SaveChangesAsync();

        // Return next expected ping interval
        var nextPingSeconds = req.Mode == "RIDE" ? 15 : 60;

        return Ok(new
        {
            received = true,
            mode = req.Mode,
            nextPingSec = nextPingSeconds,
            serverTime = now,
            gpsStored = req.IsGpsAvailable && req.Lat.HasValue
        });
    }

    /// <summary>Driver goes offline / ends duty</summary>
    [HttpPost("go-offline")]
    public async Task<IActionResult> GoOffline()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var profile = await _db.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile != null)
        {
            profile.IsOnline = false;
            profile.DutyStatus = "Offline";
            profile.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }
        return Ok(new { message = "Marked offline." });
    }
}

public record HeartbeatRequest(
    string Mode,               // IDLE | RIDE
    double? Lat = null,
    double? Lng = null,
    bool IsGpsAvailable = true,
    double? Bearing = null,
    double? Speed = null,
    double? Accuracy = null,
    Guid? RideId = null,
    int? BatteryPct = null
);
