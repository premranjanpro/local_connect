using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

/// <summary>
/// Webhook management — register, list, test, and delete webhook subscriptions.
///
/// WhatsApp/wacrm integration workflow:
///   1. Register a webhook: POST /api/v1/webhooks
///   2. Events are fired to your URL when task lifecycle events occur
///   3. Payload is HMAC-SHA256 signed (X-ShopConnector-Signature header)
///
/// Event types available:
///   task.created, task.shop_confirmed, task.shop_rejected, task.market_posted,
///   task.accepted, task.started, task.pickup_verified, task.at_drop,
///   task.completed, task.cancelled, task.geofence_alert
/// </summary>
[ApiController]
[Route("api/v1/webhooks")]
[Authorize]
public class WebhooksController : ControllerBase
{
    private readonly CoreDbContext _db;
    private readonly ShopConnector.Api.Services.IWebhookService _webhookService;

    public WebhooksController(CoreDbContext db, ShopConnector.Api.Services.IWebhookService webhookService)
    {
        _db = db;
        _webhookService = webhookService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    /// <summary>Register a new webhook endpoint</summary>
    [HttpPost]
    public async Task<IActionResult> Register([FromBody] RegisterWebhookRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var sub = new WebhookSubscription
        {
            UserId = userId.Value,
            BusinessId = req.BusinessId,
            EndpointUrl = req.EndpointUrl,
            EventFilter = string.IsNullOrEmpty(req.EventFilter) ? "*" : req.EventFilter,
            Secret = req.Secret ?? Guid.NewGuid().ToString("N"), // auto-generate secret
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _db.WebhookSubscriptions.Add(sub);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            id = sub.Id,
            endpointUrl = sub.EndpointUrl,
            eventFilter = sub.EventFilter,
            secret = sub.Secret,
            message = "Webhook registered. Use the 'secret' to verify HMAC-SHA256 signatures on X-ShopConnector-Signature header.",
            supportedEvents = new[]
            {
                "task.created", "task.shop_confirmed", "task.shop_rejected",
                "task.market_posted", "task.accepted", "task.started",
                "task.pickup_verified", "task.at_drop", "task.completed",
                "task.cancelled", "task.geofence_alert"
            }
        });
    }

    /// <summary>List all webhooks for authenticated user</summary>
    [HttpGet]
    public async Task<IActionResult> List()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var subs = await _db.WebhookSubscriptions
            .Where(w => w.UserId == userId.Value)
            .Select(w => new
            {
                w.Id,
                w.EndpointUrl,
                w.EventFilter,
                w.IsActive,
                w.CreatedAt,
                w.LastFiredAt,
                w.FailureCount
            })
            .ToListAsync();

        return Ok(subs);
    }

    /// <summary>Delete / deactivate a webhook</summary>
    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var sub = await _db.WebhookSubscriptions
            .FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId.Value);

        if (sub == null) return NotFound();

        sub.IsActive = false;
        await _db.SaveChangesAsync();

        return Ok(new { message = "Webhook deactivated." });
    }

    /// <summary>Send a test ping to the webhook endpoint</summary>
    [HttpPost("{id}/test")]
    public async Task<IActionResult> Test(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var sub = await _db.WebhookSubscriptions
            .FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId.Value);

        if (sub == null) return NotFound();

        await _webhookService.FireAsync("webhook.test", new
        {
            message = "This is a test webhook ping from ShopConnector.",
            timestamp = DateTime.UtcNow,
            webhookId = sub.Id
        });

        return Ok(new { message = "Test ping sent to " + sub.EndpointUrl });
    }
}

public record RegisterWebhookRequest(
    string EndpointUrl,
    string? EventFilter,
    Guid? BusinessId,
    string? Secret
);
