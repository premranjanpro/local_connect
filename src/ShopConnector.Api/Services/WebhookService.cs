using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using ShopConnector.Core.Entities;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Services;

/// <summary>
/// WebhookService — fires HTTP POST callbacks to registered endpoints for task lifecycle events.
///
/// WhatsApp integration (wacrm-style):
///   Register webhook URL: POST /api/v1/webhooks
///   Payload is signed with HMAC-SHA256 in X-ShopConnector-Signature header.
///   Event types mirror status transitions:
///     task.created, task.shop_confirmed, task.shop_rejected,
///     task.market_posted, task.accepted, task.started,
///     task.pickup_verified, task.at_drop, task.completed,
///     task.cancelled, task.geofence_alert
/// </summary>
public interface IWebhookService
{
    Task FireAsync(string eventType, object payload, Guid? businessId = null, Guid? userId = null);
}

public class WebhookService : IWebhookService
{
    private readonly CoreDbContext _db;
    private readonly IHttpClientFactory _httpFactory;
    private readonly ILogger<WebhookService> _logger;

    public WebhookService(CoreDbContext db, IHttpClientFactory httpFactory, ILogger<WebhookService> logger)
    {
        _db = db;
        _httpFactory = httpFactory;
        _logger = logger;
    }

    public async Task FireAsync(string eventType, object payload, Guid? businessId = null, Guid? userId = null)
    {
        // Find matching subscriptions
        var subs = await _db.WebhookSubscriptions
            .Where(w => w.IsActive &&
                        (w.BusinessId == businessId || w.UserId == userId || (businessId == null && userId == null)) &&
                        (w.EventFilter == "*" || w.EventFilter.Contains(eventType)))
            .ToListAsync();

        if (subs.Count == 0) return;

        var envelope = new
        {
            @event = eventType,
            occurred_at = DateTime.UtcNow.ToString("O"),
            data = payload
        };
        var json = JsonSerializer.Serialize(envelope);

        foreach (var sub in subs)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    var client = _httpFactory.CreateClient("webhook");
                    var content = new StringContent(json, Encoding.UTF8, "application/json");

                    // Sign with HMAC-SHA256
                    if (!string.IsNullOrEmpty(sub.Secret))
                    {
                        var sig = ComputeHmac(sub.Secret, json);
                        content.Headers.Add("X-ShopConnector-Signature", $"sha256={sig}");
                    }

                    content.Headers.Add("X-ShopConnector-Event", eventType);
                    content.Headers.Add("X-ShopConnector-Delivery", Guid.NewGuid().ToString());

                    var resp = await client.PostAsync(sub.EndpointUrl, content);
                    sub.LastFiredAt = DateTime.UtcNow;

                    if (!resp.IsSuccessStatusCode)
                    {
                        sub.FailureCount++;
                        _logger.LogWarning("[Webhook] {Event} to {Url} failed: {Status}", eventType, sub.EndpointUrl, resp.StatusCode);
                        if (sub.FailureCount >= 10)
                        {
                            sub.IsActive = false; // Auto-disable after 10 consecutive failures
                            _logger.LogWarning("[Webhook] Auto-disabled subscription {Id} after 10 failures", sub.Id);
                        }
                    }
                    else
                    {
                        sub.FailureCount = 0;
                    }

                    await _db.SaveChangesAsync();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "[Webhook] Exception firing {Event} to {Url}", eventType, sub.EndpointUrl);
                }
            });
        }
    }

    private static string ComputeHmac(string secret, string payload)
    {
        var key = Encoding.UTF8.GetBytes(secret);
        var data = Encoding.UTF8.GetBytes(payload);
        using var hmac = new HMACSHA256(key);
        var hash = hmac.ComputeHash(data);
        return Convert.ToHexString(hash).ToLower();
    }
}
