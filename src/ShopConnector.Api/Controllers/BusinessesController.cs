using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.DTOs;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1/businesses")]
public class BusinessesController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IAuditService _auditService;

    public BusinessesController(CoreDbContext dbContext, IAuditService auditService)
    {
        _dbContext = dbContext;
        _auditService = auditService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpGet("nearby")]
    public async Task<IActionResult> GetNearby(
        [FromQuery] double latitude,
        [FromQuery] double longitude,
        [FromQuery] double radiusKm = 5.0,
        [FromQuery] string? category = null)
    {
        var query = _dbContext.Businesses.Where(b => b.IsOpen);

        if (!string.IsNullOrEmpty(category))
        {
            query = query.Where(b => EF.Functions.ILike(b.Category, $"%{category}%"));
        }

        var businesses = await query.ToListAsync();

        // Calculate distance using simple spherical distance for radius filtering
        var nearby = businesses
            .Select(b => new
            {
                Business = b,
                DistanceKm = CalculateStraightLineDistance(latitude, longitude, b.Latitude, b.Longitude)
            })
            .Where(x => x.DistanceKm <= radiusKm)
            .OrderBy(x => x.DistanceKm)
            .Select(x => new
            {
                x.Business.Id,
                x.Business.Name,
                x.Business.Category,
                x.Business.Phone,
                x.Business.Address,
                x.Business.Latitude,
                x.Business.Longitude,
                x.Business.IsOpen,
                x.Business.DuesEnabledGlobally,
                x.Business.AllowedPaymentModes,
                DistanceKm = Math.Round(x.DistanceKm, 2)
            })
            .ToList();

        return Ok(nearby);
    }

    [Authorize]
    [HttpPost]
    public async Task<IActionResult> CreateBusiness([FromBody] CreateBusinessRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var business = new Business
        {
            MerchantId = userId.Value,
            Name = request.Name,
            Category = request.Category,
            Phone = request.Phone,
            Address = request.Address,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            OpenTime = request.OpenTime ?? new TimeSpan(8, 0, 0),
            CloseTime = request.CloseTime ?? new TimeSpan(22, 0, 0),
            IsOpen = true,
            DuesEnabledGlobally = true,
            AllowedPaymentModes = "Cash,Online,Dues",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _dbContext.Businesses.Add(business);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "BusinessCreated",
            "Business",
            business.Id.ToString(),
            details: $"{{\"name\":\"{business.Name}\", \"category\":\"{business.Category}\"}}"
        );

        return Ok(business);
    }

    [Authorize]
    [HttpPut("{id}/settings")]
    public async Task<IActionResult> UpdateSettings(Guid id, [FromBody] UpdateBusinessSettingsRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var business = await _dbContext.Businesses.FirstOrDefaultAsync(b => b.Id == id && b.MerchantId == userId.Value);
        if (business == null) return NotFound(new { message = "Business not found or access denied." });

        business.DuesEnabledGlobally = request.DuesEnabledGlobally;
        business.AllowedPaymentModes = request.AllowedPaymentModes;
        business.UpdatedAt = DateTime.UtcNow;

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "BusinessSettingsUpdated",
            "Business",
            business.Id.ToString(),
            details: $"{{\"duesEnabledGlobally\":{business.DuesEnabledGlobally}, \"allowedPaymentModes\":\"{business.AllowedPaymentModes}\"}}"
        );

        return Ok(business);
    }

    [HttpGet("{id}/catalog")]
    public async Task<IActionResult> GetCatalog(Guid id)
    {
        var items = await _dbContext.CatalogItems
            .Where(c => c.BusinessId == id)
            .OrderBy(c => c.Name)
            .ToListAsync();

        return Ok(items);
    }

    [Authorize]
    [HttpPost("{id}/catalog")]
    public async Task<IActionResult> AddCatalogItem(Guid id, [FromBody] CreateCatalogItemRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var business = await _dbContext.Businesses.FirstOrDefaultAsync(b => b.Id == id && b.MerchantId == userId.Value);
        if (business == null) return NotFound(new { message = "Business not found or access denied." });

        var item = new CatalogItem
        {
            BusinessId = id,
            Name = request.Name,
            Category = request.Category,
            Price = request.Price,
            Unit = request.Unit,
            ImageUrl = request.ImageUrl,
            IsInStock = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _dbContext.CatalogItems.Add(item);
        await _dbContext.SaveChangesAsync();

        return Ok(item);
    }

    private static double CalculateStraightLineDistance(double lat1, double lon1, double lat2, double lon2)
    {
        var dLat = (lat2 - lat1) * (Math.PI / 180.0);
        var dLon = (lon2 - lon1) * (Math.PI / 180.0);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(lat1 * (Math.PI / 180.0)) * Math.Cos(lat2 * (Math.PI / 180.0)) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        return 6371.0 * (2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a)));
    }
}
