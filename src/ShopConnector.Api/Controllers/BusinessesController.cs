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

    [Authorize]
    [HttpGet("my")]
    public async Task<IActionResult> GetMyBusinesses()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var businesses = await _dbContext.Businesses
            .Where(b => b.MerchantId == userId.Value)
            .OrderBy(b => b.CreatedAt)
            .ToListAsync();

        // If merchant has no registered shops yet, create a default shop
        if (businesses.Count == 0)
        {
            var defaultShop = new Business
            {
                MerchantId = userId.Value,
                Name = "My Primary Store",
                Category = "Grocery & Kirana",
                Phone = User.FindFirstValue(ClaimTypes.MobilePhone) ?? "9876543210",
                Address = "Shop #1, Main Market, Vaishali Nagar",
                Latitude = 26.9124,
                Longitude = 75.7873,
                OpenTime = new TimeSpan(8, 0, 0),
                CloseTime = new TimeSpan(22, 0, 0),
                IsOpen = true,
                DuesEnabledGlobally = true,
                AllowedPaymentModes = "Cash,Online,Dues",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _dbContext.Businesses.Add(defaultShop);
            await _dbContext.SaveChangesAsync();
            businesses.Add(defaultShop);
        }

        return Ok(businesses);
    }

    [Authorize]
    [HttpGet("{id}/delivery-boys")]
    public async Task<IActionResult> GetDeliveryBoys(Guid id)
    {
        // Get all drivers in the system and their active vehicle
        var drivers = await _dbContext.Users
            .Where(u => u.Role == "Driver")
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Phone,
                u.Status,
                AvatarUrl = u.AvatarUrl,
                DutyStatus = u.DriverProfile != null ? u.DriverProfile.DutyStatus : "Free",
                ActiveVehicleId = u.DriverProfile != null ? u.DriverProfile.ActiveVehicleId : null,
                VehicleType = u.Vehicles.Where(v => v.IsActive).Select(v => v.VehicleType).FirstOrDefault() 
                    ?? u.Vehicles.Select(v => v.VehicleType).FirstOrDefault() ?? "Bike",
                PlateNumber = u.Vehicles.Where(v => v.IsActive).Select(v => v.PlateNumber).FirstOrDefault() 
                    ?? u.Vehicles.Select(v => v.PlateNumber).FirstOrDefault() ?? "DL-01-AB-1234",
                VehicleMakeModel = u.Vehicles.Where(v => v.IsActive).Select(v => v.Make + " " + v.Model).FirstOrDefault()
                    ?? u.Vehicles.Select(v => v.Make + " " + v.Model).FirstOrDefault(),
                VehiclePhotoUrl = u.Vehicles.Where(v => v.IsActive).Select(v => v.PhotoUrl).FirstOrDefault()
                    ?? u.Vehicles.Select(v => v.PhotoUrl).FirstOrDefault(),
                Rating = 4.8m,
                ActiveTasksCount = _dbContext.Tasks.Count(t => t.AssignedDriverId == u.Id && (t.Status == "Accepted" || t.Status == "InProgress" || t.Status == "EnRoutePickup"))
            })
            .ToListAsync();

        return Ok(drivers);
    }

    [Authorize]
    [HttpPost("{id}/delivery-boys")]
    public async Task<IActionResult> AddDeliveryBoy(Guid id, [FromBody] AddShopDeliveryBoyDto request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var existingUser = await _dbContext.Users.FirstOrDefaultAsync(u => u.Phone == request.Phone);
        if (existingUser != null)
        {
            existingUser.Role = "Driver";
            if (!string.IsNullOrEmpty(request.Name)) existingUser.FullName = request.Name;
            if (!string.IsNullOrEmpty(request.PhotoUrl)) existingUser.AvatarUrl = request.PhotoUrl;
            await _dbContext.SaveChangesAsync();
            return Ok(new { message = "Existing driver linked to shop successfully", driverId = existingUser.Id });
        }

        // Create new driver account with default pin "1234"
        var newDriver = new User
        {
            Phone = request.Phone,
            FullName = request.Name,
            AvatarUrl = request.PhotoUrl,
            PinHash = BCrypt.Net.BCrypt.HashPassword("1234"),
            Role = "Driver",
            Status = "Active",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _dbContext.Users.Add(newDriver);
        await _dbContext.SaveChangesAsync();

        var profile = new DriverProfile
        {
            UserId = newDriver.Id,
            DutyStatus = "Free",
            LicenseNumber = request.DlNumber ?? "DL-" + request.Phone.Substring(Math.Max(0, request.Phone.Length - 4)),
            AcceptanceRadiusKm = 10,
            DeliveryRadiusKm = 20,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _dbContext.DriverProfiles.Add(profile);

        if (!string.IsNullOrEmpty(request.VehicleType))
        {
            var vehicle = new Vehicle
            {
                DriverId = newDriver.Id,
                BusinessId = id,
                Make = "Hero",
                Model = request.VehicleType,
                PlateNumber = request.VehicleNumber ?? "DL-01-NEW",
                VehicleType = request.VehicleType,
                PhotoUrl = request.PhotoUrl,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };
            _dbContext.Vehicles.Add(vehicle);
            await _dbContext.SaveChangesAsync();
            profile.ActiveVehicleId = vehicle.Id;
        }

        await _dbContext.SaveChangesAsync();
        return Ok(new { message = "Delivery boy created and assigned to shop team", driverId = newDriver.Id });
    }

    [Authorize]
    [HttpGet("{id}/vehicles")]
    public async Task<IActionResult> GetVehicles(Guid id)
    {
        var vehicles = await _dbContext.Vehicles
            .Include(v => v.Driver)
            .Where(v => v.BusinessId == id || _dbContext.Users.Any(u => u.Id == v.DriverId && u.Role == "Driver"))
            .OrderByDescending(v => v.IsActive)
            .Select(v => new
            {
                v.Id,
                v.Make,
                v.Model,
                v.PlateNumber,
                v.VehicleType,
                v.Color,
                v.PhotoUrl,
                v.IsActive,
                v.DriverId,
                DriverName = v.Driver != null ? v.Driver.FullName : null,
                DriverPhone = v.Driver != null ? v.Driver.Phone : null
            })
            .ToListAsync();

        return Ok(vehicles);
    }

    [Authorize]
    [HttpPost("{id}/vehicles")]
    public async Task<IActionResult> AddVehicle(Guid id, [FromBody] AddShopVehicleDto request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var driverId = request.DriverId ?? userId.Value;
        var vehicle = new Vehicle
        {
            BusinessId = id,
            DriverId = driverId,
            Make = request.Make,
            Model = request.Model,
            PlateNumber = request.PlateNumber,
            VehicleType = request.VehicleType,
            Color = string.IsNullOrWhiteSpace(request.Color) ? "Black" : request.Color,
            PhotoUrl = request.PhotoUrl,
            IsVerified = true,
            IsActive = request.DriverId != null,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Vehicles.Add(vehicle);
        await _dbContext.SaveChangesAsync();

        if (request.DriverId != null)
        {
            var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == request.DriverId.Value);
            if (profile != null)
            {
                profile.ActiveVehicleId = vehicle.Id;
                await _dbContext.SaveChangesAsync();
            }
        }

        return Ok(new { message = "Vehicle added to shop fleet successfully", vehicleId = vehicle.Id, vehicle });
    }

    [Authorize]
    [HttpPost("{id}/assign-vehicle")]
    public async Task<IActionResult> AssignVehicleToDriver(Guid id, [FromBody] AssignDriverVehicleDto request)
    {
        var vehicle = await _dbContext.Vehicles.FirstOrDefaultAsync(v => v.Id == request.VehicleId);
        if (vehicle == null) return NotFound(new { message = "Vehicle not found." });

        var driver = await _dbContext.Users.FirstOrDefaultAsync(u => u.Id == request.DriverId && u.Role == "Driver");
        if (driver == null) return NotFound(new { message = "Driver not found." });

        // Update vehicle ownership / operation
        vehicle.DriverId = driver.Id;
        vehicle.IsActive = true;

        // Reset other vehicles for this driver to inactive
        var otherVehicles = await _dbContext.Vehicles.Where(v => v.DriverId == driver.Id && v.Id != vehicle.Id).ToListAsync();
        foreach (var ov in otherVehicles)
        {
            ov.IsActive = false;
        }

        // Update driver profile active vehicle
        var profile = await _dbContext.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == driver.Id);
        if (profile != null)
        {
            profile.ActiveVehicleId = vehicle.Id;
            profile.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync();
        return Ok(new
        {
            message = $"{driver.FullName} is now assigned to drive {vehicle.Make} {vehicle.Model} ({vehicle.PlateNumber})",
            driverId = driver.Id,
            vehicleId = vehicle.Id
        });
    }

    [Authorize]
    [HttpGet("{id}/customers")]
    public async Task<IActionResult> GetCustomers(Guid id)
    {
        // Customers with khata settings or previous tasks for this business
        var customerIdsFromTasks = await _dbContext.Tasks
            .Where(t => t.BusinessId == id)
            .Select(t => t.CustomerId)
            .Distinct()
            .ToListAsync();

        var customerIdsFromKhata = await _dbContext.KhataCustomerSettings
            .Where(k => k.BusinessId == id)
            .Select(k => k.CustomerId)
            .Distinct()
            .ToListAsync();

        var allCustomerIds = customerIdsFromTasks.Union(customerIdsFromKhata).ToList();

        var customers = await _dbContext.Users
            .Where(u => allCustomerIds.Contains(u.Id) || u.Role == "Customer")
            .Take(50)
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Phone,
                AvatarUrl = u.AvatarUrl,
                Address = _dbContext.CustomerAddresses.Where(a => a.UserId == u.Id).Select(a => a.FullAddress).FirstOrDefault(),
                IsDuesAllowed = _dbContext.KhataCustomerSettings
                    .Where(k => k.BusinessId == id && k.CustomerId == u.Id)
                    .Select(k => (bool?)k.IsDuesAllowed)
                    .FirstOrDefault() ?? true,
                CreditLimit = _dbContext.KhataCustomerSettings
                    .Where(k => k.BusinessId == id && k.CustomerId == u.Id)
                    .Select(k => (decimal?)k.CreditLimit)
                    .FirstOrDefault() ?? 5000m,
                TotalOrders = _dbContext.Tasks.Count(t => t.BusinessId == id && t.CustomerId == u.Id),
                KhataBalance = _dbContext.KhataCustomerSettings
                    .Where(k => k.BusinessId == id && k.CustomerId == u.Id)
                    .Select(k => (decimal?)k.CurrentDues)
                    .FirstOrDefault() ?? 0m
            })
            .ToListAsync();

        return Ok(customers);
    }

    [Authorize]
    [HttpPost("{id}/customers")]
    public async Task<IActionResult> AddCustomer(Guid id, [FromBody] AddShopCustomerDto request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var existingUser = await _dbContext.Users.FirstOrDefaultAsync(u => u.Phone == request.Phone);
        Guid customerId;

        if (existingUser != null)
        {
            customerId = existingUser.Id;
            if (!string.IsNullOrEmpty(request.Name)) existingUser.FullName = request.Name;
            if (!string.IsNullOrEmpty(request.PhotoUrl)) existingUser.AvatarUrl = request.PhotoUrl;
        }
        else
        {
            var newUser = new User
            {
                Phone = request.Phone,
                FullName = request.Name,
                AvatarUrl = request.PhotoUrl,
                PinHash = BCrypt.Net.BCrypt.HashPassword("1234"),
                Role = "Customer",
                Status = "Active",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _dbContext.Users.Add(newUser);
            await _dbContext.SaveChangesAsync();
            customerId = newUser.Id;
        }

        var khataSetting = await _dbContext.KhataCustomerSettings
            .FirstOrDefaultAsync(k => k.BusinessId == id && k.CustomerId == customerId);

        if (khataSetting != null)
        {
            khataSetting.IsDuesAllowed = request.IsDuesAllowed;
            khataSetting.CreditLimit = request.CreditLimit;
            khataSetting.UpdatedAt = DateTime.UtcNow;
        }
        else
        {
            khataSetting = new KhataCustomerSetting
            {
                BusinessId = id,
                CustomerId = customerId,
                IsDuesAllowed = request.IsDuesAllowed,
                CreditLimit = request.CreditLimit,
                CurrentDues = 0.00m,
                UpdatedAt = DateTime.UtcNow
            };
            _dbContext.KhataCustomerSettings.Add(khataSetting);
        }

        await _dbContext.SaveChangesAsync();
        return Ok(new { message = "Customer registered & Khata profile updated", customerId });
    }


    [Authorize]
    [HttpGet("{id}/orders")]
    public async Task<IActionResult> GetShopOrders(Guid id, [FromQuery] string? status = null)
    {
        var query = _dbContext.Tasks
            .Include(t => t.Customer)
            .Include(t => t.AssignedDriver)
            .Where(t => t.BusinessId == id);

        if (!string.IsNullOrEmpty(status) && status != "All")
        {
            query = query.Where(t => t.Status == status);
        }

        var tasks = await query
            .OrderByDescending(t => t.CreatedAt)
            .Take(100)
            .Select(t => new
            {
                t.Id,
                t.CustomerId,
                CustomerName = t.Customer != null ? t.Customer.FullName : "Walk-in Customer",
                CustomerPhone = t.Customer != null ? t.Customer.Phone : "",
                t.BusinessId,
                t.AssignedDriverId,
                DriverName = t.AssignedDriver != null ? t.AssignedDriver.FullName : null,
                DriverPhone = t.AssignedDriver != null ? t.AssignedDriver.Phone : null,
                t.TaskType,
                t.Status,
                t.PickupAddress,
                t.PickupLatitude,
                t.PickupLongitude,
                t.DropoffAddress,
                t.DropoffLatitude,
                t.DropoffLongitude,
                t.PickupOtp,
                t.DropoffOtp,
                t.DistanceKm,
                t.DurationMinutes,
                t.FareAmount,
                t.PaymentMode,
                t.PaymentStatus,
                t.OrderItems,
                t.CreatedAt,
                t.AcceptedAt,
                t.CompletedAt
            })
            .ToListAsync();

        return Ok(tasks);
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
