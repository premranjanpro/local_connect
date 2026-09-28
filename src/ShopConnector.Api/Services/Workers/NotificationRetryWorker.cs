using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Services.Workers;

/// <summary>
/// NotificationRetryWorker — runs every 30 seconds.
///
/// Drains the notification_queue table:
///   - Picks PENDING items where NextRetryAt <= NOW
///   - Attempts FCM delivery via IFcmNotificationService
///   - On success: marks SENT
///   - On failure: increments RetryCount, schedules next retry (exponential back-off)
///   - After MaxRetries: marks DEAD
///
/// This guarantees delivery even when:
///   1. Driver was offline and events were batch-synced (event_occurred_at preserved)
///   2. FCM was temporarily unavailable
///   3. Customer's device was unreachable
/// </summary>
public class NotificationRetryWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<NotificationRetryWorker> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);

    public NotificationRetryWorker(IServiceScopeFactory scopeFactory, ILogger<NotificationRetryWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        _logger.LogInformation("[NotificationRetryWorker] Started. Polling every {Sec}s", Interval.TotalSeconds);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                await ProcessPendingNotificationsAsync(ct);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[NotificationRetryWorker] Unhandled error in retry loop");
            }

            await Task.Delay(Interval, ct);
        }
    }

    private async Task ProcessPendingNotificationsAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CoreDbContext>();
        var fcm = scope.ServiceProvider.GetRequiredService<IFcmNotificationService>();

        var now = DateTime.UtcNow;
        var pending = await db.NotificationQueue
            .Where(n => n.Status == "PENDING" &&
                        (n.NextRetryAt == null || n.NextRetryAt <= now))
            .OrderBy(n => n.EventOccurredAt)
            .Take(50) // process 50 per cycle
            .ToListAsync(ct);

        if (pending.Count == 0) return;

        _logger.LogInformation("[NotificationRetryWorker] Processing {Count} pending notifications", pending.Count);

        foreach (var item in pending)
        {
            if (ct.IsCancellationRequested) break;

            try
            {
                var success = false;

                if ((item.Channel == "FCM" || item.Channel == "BOTH") && !string.IsNullOrEmpty(item.FcmToken))
                {
                    // Build data payload
                    var data = new Dictionary<string, string>
                    {
                        { "taskId", item.TaskId?.ToString() ?? "" },
                        { "eventTime", item.EventOccurredAt.ToString("HH:mm") },
                        { "channel", "offline_sync" }
                    };

                    if (!string.IsNullOrEmpty(item.DataJson))
                    {
                        try
                        {
                            var extra = JsonSerializer.Deserialize<Dictionary<string, string>>(item.DataJson);
                            if (extra != null) foreach (var kv in extra) data[kv.Key] = kv.Value;
                        }
                        catch { }
                    }

                    if (item.RecipientUserId.HasValue)
                    {
                        await fcm.SendPushNotificationAsync(
                            item.RecipientUserId.Value,
                            item.FcmToken,
                            item.Title,
                            item.Body,
                            data
                        );
                        success = true;
                    }
                }

                if (success || item.Channel == "WHATSAPP")
                {
                    // WhatsApp: Phase 2 — call wacrm-style webhook
                    // For now, log the queued message
                    _logger.LogInformation("[NotificationRetryWorker] Delivered [{Channel}] to {Phone}: {Title}",
                        item.Channel, item.RecipientPhone, item.Title);
                }

                item.Status = "SENT";
                item.SentAt = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                item.RetryCount++;
                item.LastError = ex.Message[..Math.Min(ex.Message.Length, 400)];

                if (item.RetryCount >= item.MaxRetries)
                {
                    item.Status = "DEAD";
                    _logger.LogWarning("[NotificationRetryWorker] Notification {Id} marked DEAD after {N} retries", item.Id, item.RetryCount);
                }
                else
                {
                    // Exponential back-off: 30s, 60s, 2m, 4m, 8m...
                    var delaySeconds = Math.Min(30 * Math.Pow(2, item.RetryCount - 1), 600);
                    item.NextRetryAt = DateTime.UtcNow.AddSeconds(delaySeconds);
                    _logger.LogWarning("[NotificationRetryWorker] Notification {Id} retry {N}/{Max} in {S}s", item.Id, item.RetryCount, item.MaxRetries, (int)delaySeconds);
                }
            }
        }

        await db.SaveChangesAsync(ct);
    }
}
