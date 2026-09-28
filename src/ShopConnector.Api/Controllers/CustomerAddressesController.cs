using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1/customers/addresses")]
[Authorize]
public class CustomerAddressesController : ControllerBase
{
    private readonly CoreDbContext _db;

    public CustomerAddressesController(CoreDbContext db)
    {
        _db = db;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    /// <summary>
    /// GET /api/v1/customers/addresses
    /// Retrieves all saved addresses for the authenticated customer.
    /// </summary>
    [HttpGet]
    public async Task<IActionResult> GetAddresses()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var addresses = await _db.CustomerAddresses
            .Where(a => a.UserId == userId.Value)
            .OrderByDescending(a => a.IsDefault)
            .ThenByDescending(a => a.CreatedAt)
            .Select(a => new
            {
                id = a.Id,
                addressType = a.AddressType,
                title = a.Title,
                fullAddress = a.FullAddress,
                landmark = a.Landmark,
                latitude = a.Latitude,
                longitude = a.Longitude,
                isDefault = a.IsDefault,
                createdAt = a.CreatedAt
            })
            .ToListAsync();

        return Ok(addresses);
    }

    /// <summary>
    /// POST /api/v1/customers/addresses
    /// Adds a new address for the customer (Home, Office, Other). Lat/Lng is optional.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> AddAddress([FromBody] CreateAddressRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (string.IsNullOrWhiteSpace(req.FullAddress))
            return BadRequest(new { message = "Full address is required." });

        string type = string.IsNullOrWhiteSpace(req.AddressType) ? "Home" : req.AddressType.Trim();
        string title = string.IsNullOrWhiteSpace(req.Title) ? type : req.Title.Trim();

        // If marked default, unset any existing defaults
        if (req.IsDefault)
        {
            var existingDefaults = await _db.CustomerAddresses
                .Where(a => a.UserId == userId.Value && a.IsDefault)
                .ToListAsync();
            foreach (var addr in existingDefaults)
            {
                addr.IsDefault = false;
            }
        }

        var newAddress = new CustomerAddress
        {
            UserId = userId.Value,
            AddressType = type,
            Title = title,
            FullAddress = req.FullAddress.Trim(),
            Landmark = req.Landmark?.Trim(),
            Latitude = req.Latitude,
            Longitude = req.Longitude,
            IsDefault = req.IsDefault,
            CreatedAt = DateTime.UtcNow
        };

        _db.CustomerAddresses.Add(newAddress);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            id = newAddress.Id,
            addressType = newAddress.AddressType,
            title = newAddress.Title,
            fullAddress = newAddress.FullAddress,
            landmark = newAddress.Landmark,
            latitude = newAddress.Latitude,
            longitude = newAddress.Longitude,
            isDefault = newAddress.IsDefault,
            createdAt = newAddress.CreatedAt,
            message = "Address saved successfully."
        });
    }

    /// <summary>
    /// PUT /api/v1/customers/addresses/{id}
    /// Updates an existing address.
    /// </summary>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> UpdateAddress(Guid id, [FromBody] CreateAddressRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var addr = await _db.CustomerAddresses
            .FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId.Value);

        if (addr == null) return NotFound(new { message = "Address not found." });

        if (!string.IsNullOrWhiteSpace(req.AddressType)) addr.AddressType = req.AddressType.Trim();
        if (!string.IsNullOrWhiteSpace(req.Title)) addr.Title = req.Title.Trim();
        if (!string.IsNullOrWhiteSpace(req.FullAddress)) addr.FullAddress = req.FullAddress.Trim();
        addr.Landmark = req.Landmark?.Trim();
        addr.Latitude = req.Latitude;
        addr.Longitude = req.Longitude;

        if (req.IsDefault && !addr.IsDefault)
        {
            var existingDefaults = await _db.CustomerAddresses
                .Where(a => a.UserId == userId.Value && a.IsDefault && a.Id != id)
                .ToListAsync();
            foreach (var existing in existingDefaults) existing.IsDefault = false;
            addr.IsDefault = true;
        }

        await _db.SaveChangesAsync();

        return Ok(new
        {
            id = addr.Id,
            addressType = addr.AddressType,
            title = addr.Title,
            fullAddress = addr.FullAddress,
            landmark = addr.Landmark,
            latitude = addr.Latitude,
            longitude = addr.Longitude,
            isDefault = addr.IsDefault,
            message = "Address updated successfully."
        });
    }

    /// <summary>
    /// DELETE /api/v1/customers/addresses/{id}
    /// Deletes a saved address.
    /// </summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> DeleteAddress(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var addr = await _db.CustomerAddresses
            .FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId.Value);

        if (addr == null) return NotFound(new { message = "Address not found." });

        _db.CustomerAddresses.Remove(addr);
        await _db.SaveChangesAsync();

        return Ok(new { success = true, message = "Address deleted successfully." });
    }

    /// <summary>
    /// POST /api/v1/customers/addresses/{id}/set-default
    /// Sets an address as the default address.
    /// </summary>
    [HttpPost("{id:guid}/set-default")]
    public async Task<IActionResult> SetDefault(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var addr = await _db.CustomerAddresses
            .FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId.Value);

        if (addr == null) return NotFound(new { message = "Address not found." });

        var allUserAddrs = await _db.CustomerAddresses
            .Where(a => a.UserId == userId.Value)
            .ToListAsync();

        foreach (var a in allUserAddrs)
        {
            a.IsDefault = (a.Id == id);
        }

        await _db.SaveChangesAsync();

        return Ok(new { success = true, message = $"{addr.Title} set as default address." });
    }
}

public record CreateAddressRequest(
    string AddressType,     // "Home", "Office", "Other"
    string? Title,          // "My Apartment", "Main Branch"
    string FullAddress,
    string? Landmark,
    double? Latitude,
    double? Longitude,
    bool IsDefault = false
);
