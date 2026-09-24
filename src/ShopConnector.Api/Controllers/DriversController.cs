using System.Security.Claims;
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
[Route("api/v1/drivers")]
[Authorize]
public class DriversController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IAuditService _auditService;

    public DriversController(CoreDbContext dbContext, IAuditService auditService)
    {
        _dbContext = dbContext;
        _auditService = auditService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpPut("duty-status")]
    public async Task<IActionResult> UpdateDutyStatus([FromBody] UpdateDutyStatusRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile == null) return NotFound(new { message = "Driver profile not found." });

        // If driver wants to go 'Free' or online, check that they have an active vehicle selected
        if (request.Status == DriverDutyStatus.Free && profile.ActiveVehicleId == null)
        {
            return BadRequest(new { message = "Please select an active vehicle before going online." });
        }

        profile.DutyStatus = request.Status.ToString();
        profile.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "DriverStatusUpdate",
            "DriverProfile",
            profile.Id.ToString(),
            HttpContext.Connection.RemoteIpAddress?.ToString(),
            request.DeviceId,
            $"{{\"dutyStatus\":\"{profile.DutyStatus}\"}}"
        );

        return Ok(new { message = "Duty status updated successfully.", dutyStatus = profile.DutyStatus });
    }

    [HttpPut("radius")]
    public async Task<IActionResult> UpdateRadius([FromBody] UpdateRadiusRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile == null) return NotFound(new { message = "Driver profile not found." });

        profile.AcceptanceRadiusKm = request.AcceptanceRadiusKm;
        profile.DeliveryRadiusKm = request.DeliveryRadiusKm;
        profile.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "DriverRadiusUpdate",
            "DriverProfile",
            profile.Id.ToString(),
            details: $"{{\"acceptanceRadiusKm\":{profile.AcceptanceRadiusKm}, \"deliveryRadiusKm\":{profile.DeliveryRadiusKm}}}"
        );

        return Ok(new
        {
            message = "Operating radius updated successfully.",
            acceptanceRadiusKm = profile.AcceptanceRadiusKm,
            deliveryRadiusKm = profile.DeliveryRadiusKm
        });
    }

    [HttpGet("vehicles")]
    public async Task<IActionResult> GetVehicles()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var vehicles = await _dbContext.Vehicles
            .Where(v => v.DriverId == userId.Value)
            .OrderByDescending(v => v.IsActive)
            .ToListAsync();

        return Ok(vehicles);
    }

    [HttpPost("vehicles")]
    public async Task<IActionResult> AddVehicle([FromBody] AddVehicleRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var vehicle = new Vehicle
        {
            DriverId = userId.Value,
            Make = request.Make,
            Model = request.Model,
            PlateNumber = request.PlateNumber,
            VehicleType = request.VehicleType.ToString(),
            IsVerified = true,
            IsActive = false,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Vehicles.Add(vehicle);
        await _dbContext.SaveChangesAsync();

        return CreatedAtAction(nameof(GetVehicles), new { id = vehicle.Id }, vehicle);
    }

    [HttpPut("vehicles/{vehicleId}/select-active")]
    public async Task<IActionResult> SelectActiveVehicle(Guid vehicleId)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var driverVehicles = await _dbContext.Vehicles
            .Where(v => v.DriverId == userId.Value)
            .ToListAsync();

        var targetVehicle = driverVehicles.FirstOrDefault(v => v.Id == vehicleId);
        if (targetVehicle == null)
        {
            return NotFound(new { message = "Vehicle not found for this driver." });
        }

        // Only ONE vehicle can be active at a time
        foreach (var v in driverVehicles)
        {
            v.IsActive = (v.Id == vehicleId);
        }

        var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == userId.Value);
        if (profile != null)
        {
            profile.ActiveVehicleId = targetVehicle.Id;
            profile.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "VehicleSelectedActive",
            "Vehicle",
            targetVehicle.Id.ToString(),
            details: $"{{\"plateNumber\":\"{targetVehicle.PlateNumber}\", \"type\":\"{targetVehicle.VehicleType}\"}}"
        );

        return Ok(new
        {
            message = "Vehicle activated successfully.",
            activeVehicle = targetVehicle
        });
    }

    [HttpPost("banners")]
    public async Task<IActionResult> CreateIntercityBanner([FromBody] CreateIntercityBannerRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var banner = new DriverIntercityBanner
        {
            DriverId = userId.Value,
            FromCity = request.FromCity,
            ToCity = request.ToCity,
            DepartureTime = request.DepartureTime.ToUniversalTime(),
            SeatsAvailable = request.SeatsAvailable,
            ExpectedPrice = request.ExpectedPrice,
            Status = "Active",
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.DriverIntercityBanners.Add(banner);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "DriverIntercityBannerCreated",
            "DriverIntercityBanner",
            banner.Id.ToString(),
            details: $"{{\"route\":\"{banner.FromCity} -> {banner.ToCity}\", \"price\":{banner.ExpectedPrice}}}"
        );

        return Ok(banner);
    }

    [AllowAnonymous]
    [HttpGet("banners")]
    public async Task<IActionResult> GetBanners([FromQuery] string? fromCity, [FromQuery] string? toCity)
    {
        var query = _dbContext.DriverIntercityBanners
            .Include(b => b.Driver)
            .Where(b => b.Status == "Active" && b.DepartureTime > DateTime.UtcNow);

        if (!string.IsNullOrEmpty(fromCity))
            query = query.Where(b => EF.Functions.ILike(b.FromCity, $"%{fromCity}%"));

        if (!string.IsNullOrEmpty(toCity))
            query = query.Where(b => EF.Functions.ILike(b.ToCity, $"%{toCity}%"));

        var banners = await query.OrderBy(b => b.DepartureTime).Take(50).ToListAsync();

        return Ok(banners.Select(b => new
        {
            b.Id,
            b.FromCity,
            b.ToCity,
            b.DepartureTime,
            b.SeatsAvailable,
            b.ExpectedPrice,
            b.Status,
            DriverName = b.Driver?.FullName,
            DriverPhone = b.Driver?.Phone
        }));
    }
}
