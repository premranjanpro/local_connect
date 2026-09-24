using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

public record UpdateFcmTokenRequest(string FcmToken, string DeviceId);
public record SendTestPushRequest(string FcmToken, string Title, string Body);

[ApiController]
[Route("api/v1/notifications")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IFcmNotificationService _fcmService;

    public NotificationsController(CoreDbContext dbContext, IFcmNotificationService fcmService)
    {
        _dbContext = dbContext;
        _fcmService = fcmService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpPut("fcm-token")]
    public async Task<IActionResult> UpdateFcmToken([FromBody] UpdateFcmTokenRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var session = await _dbContext.UserDeviceSessions
            .FirstOrDefaultAsync(s => s.UserId == userId.Value && s.DeviceId == request.DeviceId);

        if (session != null)
        {
            session.FcmToken = request.FcmToken;
            session.LastActiveAt = DateTime.UtcNow;
            await _dbContext.SaveChangesAsync();
        }

        return Ok(new { message = "FCM token updated successfully.", deviceId = request.DeviceId });
    }

    [HttpPost("test-push")]
    public async Task<IActionResult> SendTestPush([FromBody] SendTestPushRequest request)
    {
        var userId = GetUserId();
        var success = await _fcmService.SendPushNotificationAsync(
            userId,
            request.FcmToken,
            request.Title,
            request.Body,
            new Dictionary<string, string> { { "type", "test_alert" }, { "timestamp", DateTime.UtcNow.ToString("o") } }
        );

        return Ok(new { success, message = success ? "Push notification sent/simulated successfully." : "Failed to dispatch push notification." });
    }
}
