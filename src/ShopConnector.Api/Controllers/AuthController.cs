using System.Security.Claims;
using BCrypt.Net;
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
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IJwtTokenService _jwtTokenService;
    private readonly IAuditService _auditService;

    public AuthController(CoreDbContext dbContext, IJwtTokenService jwtTokenService, IAuditService auditService)
    {
        _dbContext = dbContext;
        _jwtTokenService = jwtTokenService;
        _auditService = auditService;
    }

    [HttpPost("login-pin")]
    public async Task<IActionResult> LoginWithPin([FromBody] LoginPinRequest request)
    {
        var user = await _dbContext.Users
            .Include(u => u.DriverProfile)
            .FirstOrDefaultAsync(u => u.Phone == request.Phone);

        if (user == null)
        {
            return Unauthorized(new { message = "Invalid phone number or PIN." });
        }

        // Verify PIN (supports default "1234" for rapid testing or hashed PIN)
        bool isPinValid = request.Pin == "1234" || BCrypt.Net.BCrypt.Verify(request.Pin, user.PinHash);
        if (!isPinValid)
        {
            return Unauthorized(new { message = "Invalid phone number or PIN." });
        }

        // CRITICAL DRIVER CONCURRENCY RULE:
        // A driver cannot log in to device B if actively running an order on device A
        if (user.Role == UserRole.Driver.ToString())
        {
            var activeTask = await _dbContext.Tasks
                .Include(t => t.Assignments)
                .Where(t => t.AssignedDriverId == user.Id &&
                            (t.Status == PlatformTaskStatus.Accepted.ToString() ||
                             t.Status == PlatformTaskStatus.EnRoutePickup.ToString() ||
                             t.Status == PlatformTaskStatus.ArrivedPickup.ToString() ||
                             t.Status == PlatformTaskStatus.InProgress.ToString()))
                .FirstOrDefaultAsync();

            if (activeTask != null)
            {
                var activeAssignment = activeTask.Assignments
                    .FirstOrDefault(a => a.DriverId == user.Id && a.Status == TaskAssignmentStatus.Accepted.ToString());

                if (activeAssignment != null && activeAssignment.DeviceId != request.DeviceId)
                {
                    return StatusCode(StatusCodes.Status409Conflict, new
                    {
                        message = "Driver is currently executing an active order on another device. Multi-device execution is restricted.",
                        activeTaskId = activeTask.Id,
                        activeDeviceId = activeAssignment.DeviceId
                    });
                }
            }
        }

        // Deactivate previous sessions for this user on other devices if idle
        var existingSessions = await _dbContext.UserDeviceSessions
            .Where(s => s.UserId == user.Id && s.IsActive && s.DeviceId != request.DeviceId)
            .ToListAsync();

        foreach (var sess in existingSessions)
        {
            sess.IsActive = false;
            sess.RevokedAt = DateTime.UtcNow;
        }

        // Upsert device session
        var currentSession = await _dbContext.UserDeviceSessions
            .FirstOrDefaultAsync(s => s.UserId == user.Id && s.DeviceId == request.DeviceId);

        var ip = HttpContext.Connection.RemoteIpAddress?.ToString();

        if (currentSession == null)
        {
            currentSession = new UserDeviceSession
            {
                UserId = user.Id,
                DeviceId = request.DeviceId,
                DeviceModel = request.DeviceModel ?? "Unknown",
                OsVersion = request.OsVersion ?? "Unknown",
                AppVersion = request.AppVersion ?? "1.0.0",
                FcmToken = request.FcmToken,
                IpAddress = ip,
                IsActive = true,
                LoggedInAt = DateTime.UtcNow,
                LastActiveAt = DateTime.UtcNow
            };
            _dbContext.UserDeviceSessions.Add(currentSession);
        }
        else
        {
            currentSession.IsActive = true;
            currentSession.RevokedAt = null;
            currentSession.LastActiveAt = DateTime.UtcNow;
            currentSession.IpAddress = ip;
            if (!string.IsNullOrEmpty(request.FcmToken)) currentSession.FcmToken = request.FcmToken;
        }

        await _dbContext.SaveChangesAsync();

        // Generate Token
        var token = _jwtTokenService.GenerateToken(user, request.DeviceId, out var expiresAt);

        // Audit Log
        await _auditService.LogActionAsync(
            user.Id,
            "UserLogin",
            "User",
            user.Id.ToString(),
            ip,
            request.DeviceId,
            $"{{\"role\":\"{user.Role}\", \"deviceModel\":\"{request.DeviceModel}\"}}"
        );

        return Ok(new AuthResponse(
            UserId: user.Id,
            Phone: user.Phone,
            FullName: user.FullName,
            Role: user.Role,
            Token: token,
            ExpiresAt: expiresAt,
            DeviceId: request.DeviceId
        ));
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var existingUser = await _dbContext.Users.FirstOrDefaultAsync(u => u.Phone == request.Phone);
        if (existingUser != null)
        {
            return BadRequest(new { message = "User with this mobile number already exists." });
        }

        var pinHash = BCrypt.Net.BCrypt.HashPassword(string.IsNullOrEmpty(request.Pin) ? "1234" : request.Pin);

        var user = new User
        {
            Phone = request.Phone,
            PinHash = pinHash,
            FullName = request.FullName,
            Role = request.Role.ToString(),
            Email = request.Email,
            Status = UserStatus.Active.ToString(),
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _dbContext.Users.Add(user);

        // Auto-create driver profile if registering as driver
        if (request.Role == UserRole.Driver)
        {
            var driverProfile = new DriverProfile
            {
                UserId = user.Id,
                DutyStatus = DriverDutyStatus.OffDuty.ToString(),
                AcceptanceRadiusKm = 1.00m,
                DeliveryRadiusKm = 10.00m,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _dbContext.DriverProfiles.Add(driverProfile);
        }

        var ip = HttpContext.Connection.RemoteIpAddress?.ToString();
        var session = new UserDeviceSession
        {
            UserId = user.Id,
            DeviceId = request.DeviceId,
            DeviceModel = request.DeviceModel ?? "Unknown",
            OsVersion = request.OsVersion ?? "Unknown",
            AppVersion = request.AppVersion ?? "1.0.0",
            IpAddress = ip,
            IsActive = true,
            LoggedInAt = DateTime.UtcNow,
            LastActiveAt = DateTime.UtcNow
        };
        _dbContext.UserDeviceSessions.Add(session);

        await _dbContext.SaveChangesAsync();

        var token = _jwtTokenService.GenerateToken(user, request.DeviceId, out var expiresAt);

        await _auditService.LogActionAsync(
            user.Id,
            "UserRegistration",
            "User",
            user.Id.ToString(),
            ip,
            request.DeviceId,
            $"{{\"role\":\"{user.Role}\"}}"
        );

        return Ok(new AuthResponse(
            UserId: user.Id,
            Phone: user.Phone,
            FullName: user.FullName,
            Role: user.Role,
            Token: token,
            ExpiresAt: expiresAt,
            DeviceId: request.DeviceId
        ));
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> GetCurrentUser()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(userIdStr, out var userId)) return Unauthorized();

        var user = await _dbContext.Users
            .Include(u => u.DriverProfile)
            .Include(u => u.Vehicles)
            .Include(u => u.Businesses)
            .FirstOrDefaultAsync(u => u.Id == userId);

        if (user == null) return NotFound();

        var deviceId = User.FindFirstValue("device_id");

        return Ok(new
        {
            user.Id,
            user.Phone,
            user.FullName,
            user.Email,
            user.Role,
            user.Status,
            user.AvatarUrl,
            DriverProfile = user.DriverProfile != null ? new
            {
                user.DriverProfile.DutyStatus,
                user.DriverProfile.AcceptanceRadiusKm,
                user.DriverProfile.DeliveryRadiusKm,
                user.DriverProfile.ActiveVehicleId,
                user.DriverProfile.CurrentLatitude,
                user.DriverProfile.CurrentLongitude
            } : null,
            ActiveVehiclesCount = user.Vehicles.Count,
            BusinessesCount = user.Businesses.Count,
            CurrentDeviceId = deviceId
        });
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var deviceId = User.FindFirstValue("device_id");
        if (Guid.TryParse(userIdStr, out var userId) && !string.IsNullOrEmpty(deviceId))
        {
            var session = await _dbContext.UserDeviceSessions
                .FirstOrDefaultAsync(s => s.UserId == userId && s.DeviceId == deviceId && s.IsActive);

            if (session != null)
            {
                session.IsActive = false;
                session.RevokedAt = DateTime.UtcNow;
                await _dbContext.SaveChangesAsync();
            }

            await _auditService.LogActionAsync(
                userId,
                "UserLogout",
                "UserDeviceSession",
                session?.Id.ToString() ?? deviceId,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                deviceId
            );
        }

        return Ok(new { message = "Logged out successfully." });
    }
}
