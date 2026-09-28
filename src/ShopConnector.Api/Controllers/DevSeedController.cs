using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Enums;
using ShopConnector.Infrastructure.Data;
using System.Security.Cryptography;
using System.Text;

namespace ShopConnector.Api.Controllers;

/// <summary>
/// Demo seed — creates realistic data for UI testing.
/// DELETE THIS IN PRODUCTION.
/// GET /api/v1/dev/seed  — creates demo users, business, tasks, ride
/// GET /api/v1/dev/seed-status — shows what's seeded
/// </summary>
[ApiController]
[Route("api/v1/dev")]
public class DevSeedController : ControllerBase
{
    private readonly CoreDbContext _db;

    public DevSeedController(CoreDbContext db) => _db = db;

    [HttpGet("seed")]
    public async Task<IActionResult> Seed()
    {
        // Idempotent — skip if already seeded
        if (await _db.Users.AnyAsync(u => u.Phone == "9999000001"))
            return Ok(new { message = "Already seeded.", hint = "GET /api/v1/dev/seed-status for credentials" });

        var rand = new Random(42);

        // ── 1. Users ────────────────────────────────────────────────────
        var customer1 = MakeUser("9999000001", "Priya Sharma", UserRole.Customer);
        var customer2 = MakeUser("9999000002", "Rahul Verma", UserRole.Customer);
        var customer3 = MakeUser("9999000003", "Anjali Gupta", UserRole.Customer);
        var customer4 = MakeUser("9999000004", "Vikram Singh", UserRole.Customer);
        var merchant  = MakeUser("9999000010", "Ramesh Agarwal", UserRole.Merchant);
        var driver1   = MakeUser("9999000020", "Deepak Yadav", UserRole.Driver);
        var driver2   = MakeUser("9999000021", "Mohit Kumar", UserRole.Driver);

        _db.Users.AddRange(customer1, customer2, customer3, customer4, merchant, driver1, driver2);
        await _db.SaveChangesAsync();

        // ── 2. Business ──────────────────────────────────────────────────
        var biz = new Business
        {
            MerchantId = merchant.Id,
            Name = "Ramesh Kirana & General Store",
            Category = "Grocery",
            Phone = "9999000010",
            Address = "Shop 12, Sindhi Colony, Jaipur",
            Latitude = 26.9124, Longitude = 75.7873,
            IsOpen = true
        };
        _db.Businesses.Add(biz);
        await _db.SaveChangesAsync();

        // ── 3. Driver Vehicles & Profiles (Multiple vehicles per driver, 1 active) ─────────
        driver1.AvatarUrl = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300";
        driver2.AvatarUrl = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300";

        var v1_bike = new Vehicle
        {
            DriverId = driver1.Id,
            Make = "Hero",
            Model = "Splendor Plus",
            PlateNumber = "RJ14-SC-7890",
            VehicleType = "Bike",
            Color = "Flame Red",
            PhotoUrl = "https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500",
            IsVerified = true,
            IsActive = true
        };

        var v2_car = new Vehicle
        {
            DriverId = driver1.Id,
            Make = "Maruti Suzuki",
            Model = "Swift VXI",
            PlateNumber = "RJ14-CP-1234",
            VehicleType = "CabSedan",
            Color = "Arctic White",
            PhotoUrl = "https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=500",
            IsVerified = true,
            IsActive = false // multiple vehicles, currently online with bike
        };

        var v3_auto = new Vehicle
        {
            DriverId = driver2.Id,
            Make = "Bajaj",
            Model = "RE Compact Auto",
            PlateNumber = "RJ14-TR-5566",
            VehicleType = "Auto",
            Color = "Yellow & Green",
            PhotoUrl = "https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=500",
            IsVerified = true,
            IsActive = true
        };

        _db.Vehicles.AddRange(v1_bike, v2_car, v3_auto);
        await _db.SaveChangesAsync();

        var dp1 = new DriverProfile
        {
            UserId = driver1.Id,
            ActiveVehicleId = v1_bike.Id,
            LicenseNumber = "DL-1420110012345",
            DutyStatus = DriverDutyStatus.Free.ToString(),
            IsOnline = true,
            TrackingMode = "IDLE",
            CurrentLatitude = 26.9124,
            CurrentLongitude = 75.7873,
            IsVerified = true,
            Rating = 4.8m
        };
        var dp2 = new DriverProfile
        {
            UserId = driver2.Id,
            ActiveVehicleId = v3_auto.Id,
            LicenseNumber = "DL-1420180098765",
            DutyStatus = DriverDutyStatus.Free.ToString(),
            IsOnline = true,
            TrackingMode = "IDLE",
            CurrentLatitude = 26.9200,
            CurrentLongitude = 75.7900,
            IsVerified = true,
            Rating = 4.6m
        };
        _db.DriverProfiles.AddRange(dp1, dp2);

        // ── 4. Catalog items ──────────────────────────────────────────────
        var items = new[] {
            ("Aloo (Potato) 5kg", 85m, "kg"), ("Pyaz (Onion) 5kg", 95m, "kg"),
            ("Chawal Basmati 1kg", 120m, "kg"), ("Dal Arhar 500g", 75m, "g"),
            ("Sarso Tel 1L", 185m, "L"), ("Doodh Pouch 500ml", 28m, "ml"),
        };
        foreach (var (name, price, unit) in items)
        {
            _db.CatalogItems.Add(new CatalogItem
            {
                BusinessId = biz.Id, Name = name,
                Price = price, Unit = unit, IsInStock = true
            });
        }
        await _db.SaveChangesAsync();

        // ── 5. Tasks (orders) ─────────────────────────────────────────────
        // Task 1: Simple delivery — Priya ordered groceries
        var task1 = new TaskEntity
        {
            CustomerId = customer1.Id,
            BusinessId = biz.Id,
            AssignedDriverId = driver1.Id,
            TaskType = "Delivery",
            Status = "Accepted",
            PickupAddress = "Ramesh Kirana, Shop 12, Sindhi Colony",
            PickupLatitude = 26.9124, PickupLongitude = 75.7873,
            DropoffAddress = "B-45, Vaishali Nagar, Jaipur",
            DropoffLatitude = 26.9218, DropoffLongitude = 75.7521,
            PickupOtp = "483921", DropoffOtp = "729104",
            IsPickupOtpRequired = true, IsDropOtpRequired = true,
            FareAmount = 60, DistanceKm = 4.2m, DurationMinutes = 18,
            PaymentMode = "Cash", PaymentStatus = "Pending",
            OrderItems = "Aloo 5kg, Pyaz 5kg, Chawal 1kg",
            ShopConfirmedAt = DateTime.UtcNow.AddMinutes(-10),
            ShopConfirmedBy = merchant.Id,
            CreatedAt = DateTime.UtcNow.AddMinutes(-20)
        };

        // Task 2: School run — 3 student pickups → 1 school
        var task2 = new TaskEntity
        {
            CustomerId = customer2.Id,
            AssignedDriverId = driver1.Id,
            TaskType = "SchoolRun",
            Status = "EN_ROUTE_PICKUP",
            PickupAddress = "C-12, Shyam Nagar (Rahul)",
            PickupLatitude = 26.9310, PickupLongitude = 75.7650,
            DropoffAddress = "Delhi Public School, Jaipur",
            DropoffLatitude = 26.8989, DropoffLongitude = 75.8201,
            IsPickupOtpRequired = false, IsDropOtpRequired = false,
            FareAmount = 350, DistanceKm = 8.5m, DurationMinutes = 35,
            PaymentMode = "Online", PaymentStatus = "Paid",
            OrderItems = "3 Students",
            CreatedAt = DateTime.UtcNow.AddHours(-1)
        };

        // Task 3: Market delivery — driver2, broadcasting
        var task3 = new TaskEntity
        {
            CustomerId = customer3.Id,
            BusinessId = biz.Id,
            TaskType = "Delivery",
            Status = "Broadcasting",
            PickupAddress = "Ramesh Kirana, Shop 12, Sindhi Colony",
            PickupLatitude = 26.9124, PickupLongitude = 75.7873,
            DropoffAddress = "A-8, Mansarovar, Jaipur",
            DropoffLatitude = 26.8712, DropoffLongitude = 75.8041,
            IsPickupOtpRequired = true, IsDropOtpRequired = false,
            PickupOtp = "331874",
            FareAmount = 80, DistanceKm = 6.1m, DurationMinutes = 25,
            IsMarketPosted = true, MarketFareOffer = 80, MarketPostedAt = DateTime.UtcNow.AddMinutes(-5),
            PaymentMode = "Online", PaymentStatus = "Pending",
            OrderItems = "Dal 500g, Sarso Tel 1L",
            CreatedAt = DateTime.UtcNow.AddMinutes(-8)
        };

        // Task 4: Completed order
        var task4 = new TaskEntity
        {
            CustomerId = customer4.Id,
            BusinessId = biz.Id,
            AssignedDriverId = driver2.Id,
            TaskType = "Delivery",
            Status = "Completed",
            PickupAddress = "Ramesh Kirana, Shop 12, Sindhi Colony",
            PickupLatitude = 26.9124, PickupLongitude = 75.7873,
            DropoffAddress = "D-22, Pratap Nagar, Jaipur",
            DropoffLatitude = 26.9445, DropoffLongitude = 75.8100,
            IsPickupOtpRequired = true, IsDropOtpRequired = true,
            PickupOtp = "112233", DropoffOtp = "445566",
            FareAmount = 45, DistanceKm = 3.2m, DurationMinutes = 14,
            PaymentMode = "Cash", PaymentStatus = "Paid",
            OrderItems = "Doodh 500ml × 2",
            ShopConfirmedAt = DateTime.UtcNow.AddHours(-3),
            ShopConfirmedBy = merchant.Id,
            CompletedAt = DateTime.UtcNow.AddHours(-2),
            CreatedAt = DateTime.UtcNow.AddHours(-4)
        };

        _db.Tasks.AddRange(task1, task2, task3, task4);
        await _db.SaveChangesAsync();

        // ── 6. Task Stops — School run stops ─────────────────────────────
        var schoolStops = new[]
        {
            new TaskStop
            {
                TaskId = task2.Id, StopSequence = 1, StopType = "PICKUP",
                Address = "C-12, Shyam Nagar (Rahul Verma)", Latitude = 26.9310, Longitude = 75.7650,
                RecipientUserId = customer2.Id, RecipientLabel = "Rahul Verma", RecipientPhone = "9999000002",
                IsOtpRequired = false, GeofenceRadiusMeters = 200, Status = "DRIVER_APPROACHING",
                ProximityNotified = true, ProximityNotifiedAt = DateTime.UtcNow.AddMinutes(-3)
            },
            new TaskStop
            {
                TaskId = task2.Id, StopSequence = 2, StopType = "PICKUP",
                Address = "E-7, Chitrakoot (Anjali Gupta)", Latitude = 26.9380, Longitude = 75.7720,
                RecipientUserId = customer3.Id, RecipientLabel = "Anjali Gupta", RecipientPhone = "9999000003",
                IsOtpRequired = false, GeofenceRadiusMeters = 200, Status = "PENDING"
            },
            new TaskStop
            {
                TaskId = task2.Id, StopSequence = 3, StopType = "PICKUP",
                Address = "G-3, Vidhyadhar Nagar (Vikram Singh)", Latitude = 26.9451, Longitude = 75.7801,
                RecipientUserId = customer4.Id, RecipientLabel = "Vikram Singh", RecipientPhone = "9999000004",
                IsOtpRequired = false, GeofenceRadiusMeters = 200, Status = "PENDING"
            },
            new TaskStop
            {
                TaskId = task2.Id, StopSequence = 4, StopType = "DROP",
                Address = "Delhi Public School, Jaipur", Latitude = 26.8989, Longitude = 75.8201,
                RecipientLabel = "School Gate", RecipientPhone = "0141-4001200",
                IsOtpRequired = false, GeofenceRadiusMeters = 300, Status = "PENDING"
            },
        };
        _db.TaskStops.AddRange(schoolStops);

        // Grocery delivery stops
        var groceryStops = new[]
        {
            new TaskStop
            {
                TaskId = task1.Id, StopSequence = 1, StopType = "PICKUP",
                Address = "Ramesh Kirana, Shop 12, Sindhi Colony", Latitude = 26.9124, Longitude = 75.7873,
                RecipientLabel = "Shop Counter", RecipientPhone = "9999000010",
                IsOtpRequired = true, Otp = "483921", GeofenceRadiusMeters = 100, Status = "PENDING"
            },
            new TaskStop
            {
                TaskId = task1.Id, StopSequence = 2, StopType = "DROP",
                Address = "B-45, Vaishali Nagar, Jaipur", Latitude = 26.9218, Longitude = 75.7521,
                RecipientUserId = customer1.Id, RecipientLabel = "Priya Sharma", RecipientPhone = "9999000001",
                IsOtpRequired = true, Otp = "729104", GeofenceRadiusMeters = 150, Status = "PENDING"
            },
        };
        _db.TaskStops.AddRange(groceryStops);

        // ── 7. Ride Session (driver1's active ride) ────────────────────────
        var ride = new RideSession
        {
            DriverId = driver1.Id,
            RideName = "Morning School Run – Route A",
            Status = "ACTIVE",
            StartedAt = DateTime.UtcNow.AddMinutes(-22),
            StartLat = 26.9200, StartLng = 75.7700,
            TotalKm = 2.4m, TotalMinutes = 22,
            CreatedAt = DateTime.UtcNow.AddMinutes(-25)
        };
        _db.RideSessions.Add(ride);
        await _db.SaveChangesAsync();

        var rideTasks = new[]
        {
            new RideTask { RideSessionId = ride.Id, TaskId = task2.Id, PlannedSequence = 1, Status = "PENDING" },
            new RideTask { RideSessionId = ride.Id, TaskId = task1.Id, PlannedSequence = 2, Status = "PENDING" },
        };
        _db.RideTasks.AddRange(rideTasks);

        // ── 8. Delivery logs ──────────────────────────────────────────────
        _db.TaskDeliveryLogs.AddRange(
            new TaskDeliveryLog
            {
                TaskId = task2.Id, DriverId = driver1.Id,
                EventType = "TripStarted", FromStatus = "Accepted", ToStatus = "EN_ROUTE_PICKUP",
                DriverLat = 26.9200, DriverLng = 75.7700, GeofenceStatus = "N/A",
                Notes = "Driver started ride — 3 student pickups scheduled",
                OccurredAt = DateTime.UtcNow.AddMinutes(-22)
            },
            new TaskDeliveryLog
            {
                TaskId = task4.Id, DriverId = driver2.Id,
                EventType = "Delivered", FromStatus = "AT_DROP", ToStatus = "Completed",
                DriverLat = 26.9445, DriverLng = 75.8100,
                ExpectedLat = 26.9445, ExpectedLng = 75.8100,
                DistanceFromExpectedMeters = 32, GeofenceStatus = "OK",
                Notes = "✅ Driver was within 32m of drop point. Verified.",
                OccurredAt = DateTime.UtcNow.AddHours(-2)
            }
        );

        // ── 9. Device sessions (FCM tokens for demo) ─────────────────────
        _db.UserDeviceSessions.AddRange(
            new UserDeviceSession { UserId = customer1.Id, DeviceId = "demo-device-c1", FcmToken = "demo_fcm_c1", IsActive = true },
            new UserDeviceSession { UserId = customer2.Id, DeviceId = "demo-device-c2", FcmToken = "demo_fcm_c2", IsActive = true },
            new UserDeviceSession { UserId = driver1.Id, DeviceId = "demo-device-d1", FcmToken = "demo_fcm_d1", IsActive = true },
            new UserDeviceSession { UserId = merchant.Id, DeviceId = "demo-device-m1", FcmToken = "demo_fcm_m1", IsActive = true }
        );

        await _db.SaveChangesAsync();

        return Ok(new
        {
            message = "✅ Demo data seeded successfully!",
            credentials = new[]
            {
                new { role = "Customer", phone = "9999000001", name = "Priya Sharma", pin = "1234" },
                new { role = "Customer", phone = "9999000002", name = "Rahul Verma", pin = "1234" },
                new { role = "Customer", phone = "9999000003", name = "Anjali Gupta", pin = "1234" },
                new { role = "Merchant", phone = "9999000010", name = "Ramesh Agarwal", pin = "1234" },
                new { role = "Driver", phone = "9999000020", name = "Deepak Yadav (active ride)", pin = "1234" },
                new { role = "Driver", phone = "9999000021", name = "Mohit Kumar", pin = "1234" },
            },
            activeRideId = ride.Id,
            taskIds = new
            {
                groceryDelivery = task1.Id,
                schoolRun = task2.Id,
                marketBroadcast = task3.Id,
                completed = task4.Id,
            },
            businessId = biz.Id
        });
    }

    [HttpGet("seed-status")]
    public async Task<IActionResult> SeedStatus()
    {
        return Ok(new
        {
            users = await _db.Users.CountAsync(),
            tasks = await _db.Tasks.CountAsync(),
            stops = await _db.TaskStops.CountAsync(),
            rides = await _db.RideSessions.CountAsync(),
            businesses = await _db.Businesses.CountAsync(),
            seeded = await _db.Users.AnyAsync(u => u.Phone == "9999000001"),
            loginHint = "All demo accounts use PIN: 1234",
            apiBaseUrl = "http://localhost:5038"
        });
    }

    private static User MakeUser(string phone, string name, UserRole role)
    {
        // PIN = 1234, SHA256 hashed (matches AuthController logic)
        var pinHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes("1234"))).ToLower();
        return new User
        {
            Phone = phone, FullName = name, Role = role.ToString(),
            PinHash = pinHash, Status = UserStatus.Active.ToString(), CreatedAt = DateTime.UtcNow
        };
    }
}
