using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

public record InitiateCallRequest(Guid RecipientUserId, string RecipientRole, string? TaskId, string? CallType);
public record RespondCallRequest(string Action, Guid CallerUserId);

[ApiController]
[Route("api/v1/calls")]
[Authorize]
public class CallsController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly ILiveKitService _liveKitService;
    private readonly IFcmNotificationService _fcmService;
    private readonly IAuditService _auditService;
    private readonly ILogger<CallsController> _logger;

    public CallsController(
        CoreDbContext dbContext,
        ILiveKitService liveKitService,
        IFcmNotificationService fcmService,
        IAuditService auditService,
        ILogger<CallsController> logger)
    {
        _dbContext = dbContext;
        _liveKitService = liveKitService;
        _fcmService = fcmService;
        _auditService = auditService;
        _logger = logger;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    private string GetUserName()
    {
        return User.FindFirstValue(ClaimTypes.Name) ?? "User";
    }

    private string GetUserRole()
    {
        return User.FindFirstValue(ClaimTypes.Role) ?? "Customer";
    }

    [HttpPost("start")]
    public async Task<IActionResult> StartCall([FromBody] InitiateCallRequest request)
    {
        var callerId = GetUserId();
        if (callerId == null) return Unauthorized();

        var callerName = GetUserName();
        var callerRole = GetUserRole();

        var recipient = await _dbContext.Users.FindAsync(request.RecipientUserId);
        if (recipient == null)
        {
            return NotFound(new { error = "Recipient user not found." });
        }

        var callId = Guid.NewGuid();
        var roomName = $"call_{callId:N}";
        var liveKitUrl = _liveKitService.GetLiveKitUrl();

        var callerToken = _liveKitService.GenerateAccessToken(roomName, callerId.Value.ToString(), callerName);
        var calleeToken = _liveKitService.GenerateAccessToken(roomName, recipient.Id.ToString(), recipient.FullName);

        // Find active device FCM token for recipient
        var session = await _dbContext.UserDeviceSessions
            .Where(s => s.UserId == recipient.Id && !string.IsNullOrEmpty(s.FcmToken))
            .OrderByDescending(s => s.LastActiveAt)
            .FirstOrDefaultAsync();

        var recipientFcmToken = session?.FcmToken ?? "simulated_recipient_fcm_token";

        // Dispatch High-Priority Call FCM push notification
        var pushData = new Dictionary<string, string>
        {
            { "type", "incoming_call" },
            { "callId", callId.ToString() },
            { "callerId", callerId.Value.ToString() },
            { "callerName", callerName },
            { "callerRole", callerRole },
            { "roomName", roomName },
            { "liveKitUrl", liveKitUrl },
            { "calleeToken", calleeToken },
            { "taskId", request.TaskId ?? "" },
            { "priority", "high" },
            { "timestamp", DateTime.UtcNow.ToString("o") }
        };

        await _fcmService.SendPushNotificationAsync(
            recipient.Id,
            recipientFcmToken,
            $"📞 Incoming Call from {callerName}",
            $"{callerRole} is calling regarding your order/delivery.",
            pushData
        );

        _logger.LogInformation("VoIP Call initiated: CallId={CallId}, Caller={Caller}, Recipient={Recipient}", callId, callerName, recipient.FullName);

        return Ok(new
        {
            callId = callId.ToString(),
            roomName,
            liveKitUrl,
            callerToken,
            calleeToken,
            recipientId = recipient.Id,
            recipientName = recipient.FullName,
            recipientRole = request.RecipientRole,
            status = "Ringing"
        });
    }

    [HttpPost("{callId}/respond")]
    public async Task<IActionResult> RespondCall(string callId, [FromBody] RespondCallRequest request)
    {
        var calleeId = GetUserId();
        var calleeName = GetUserName();

        var callerSession = await _dbContext.UserDeviceSessions
            .Where(s => s.UserId == request.CallerUserId && !string.IsNullOrEmpty(s.FcmToken))
            .OrderByDescending(s => s.LastActiveAt)
            .FirstOrDefaultAsync();

        var callerFcmToken = callerSession?.FcmToken ?? "simulated_caller_fcm_token";

        var pushData = new Dictionary<string, string>
        {
            { "type", "call_response" },
            { "callId", callId },
            { "action", request.Action },
            { "calleeName", calleeName },
            { "timestamp", DateTime.UtcNow.ToString("o") }
        };

        await _fcmService.SendPushNotificationAsync(
            request.CallerUserId,
            callerFcmToken,
            $"Call {request.Action}",
            $"{calleeName} has {request.Action.ToLower()}ed your call.",
            pushData
        );

        return Ok(new { callId, action = request.Action, message = $"Call response '{request.Action}' dispatched." });
    }

    [HttpPost("{callId}/end")]
    public IActionResult EndCall(string callId)
    {
        _logger.LogInformation("Call session {CallId} ended.", callId);
        return Ok(new { callId, status = "Ended", message = "Call session terminated." });
    }
}
