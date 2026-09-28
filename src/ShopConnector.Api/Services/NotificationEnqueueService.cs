using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Services;

/// <summary>
/// INotificationEnqueueService — creates persisted notification queue entries.
///
/// Every notification goes through this service so:
///   1. It is persisted to DB before any FCM attempt
///   2. If FCM fails, NotificationRetryWorker retries automatically
///   3. Offline events get queued with event_occurred_at set to the ACTUAL event time
///      so the message says "Your order was picked up at 12:30 PM" even if
///      the notification arrives at 1:15 PM after connectivity restores
/// </summary>
public interface INotificationEnqueueService
{
    Task EnqueueAsync(
        string title,
        string body,
        Guid? recipientUserId = null,
        string? recipientPhone = null,
        Guid? taskId = null,
        Guid? taskStopId = null,
        string channel = "FCM",
        Dictionary<string, string>? extraData = null,
        DateTime? eventOccurredAt = null,
        bool attemptImmediately = true
    );
}

public class NotificationEnqueueService : INotificationEnqueueService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IFcmNotificationService _fcmService;

    public NotificationEnqueueService(IServiceScopeFactory scopeFactory, IFcmNotificationService fcmService)
    {
        _scopeFactory = scopeFactory;
        _fcmService = fcmService;
    }

    public async Task EnqueueAsync(
        string title, string body,
        Guid? recipientUserId = null,
        string? recipientPhone = null,
        Guid? taskId = null,
        Guid? taskStopId = null,
        string channel = "FCM",
        Dictionary<string, string>? extraData = null,
        DateTime? eventOccurredAt = null,
        bool attemptImmediately = true)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CoreDbContext>();

        // Find FCM token for recipient
        string? fcmToken = null;
        if (recipientUserId.HasValue)
        {
            var session = await db.UserDeviceSessions
                .Where(s => s.UserId == recipientUserId.Value && s.IsActive && !string.IsNullOrEmpty(s.FcmToken))
                .OrderByDescending(s => s.LastActiveAt)
                .FirstOrDefaultAsync();
            fcmToken = session?.FcmToken;
        }

        var item = new NotificationQueueItem
        {
            TaskId = taskId,
            TaskStopId = taskStopId,
            RecipientUserId = recipientUserId,
            RecipientPhone = recipientPhone,
            FcmToken = fcmToken,
            Channel = channel,
            Title = title,
            Body = body,
            DataJson = extraData != null ? System.Text.Json.JsonSerializer.Serialize(extraData) : null,
            EventOccurredAt = eventOccurredAt ?? DateTime.UtcNow,
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow,
            NextRetryAt = DateTime.UtcNow // ready immediately
        };

        db.NotificationQueue.Add(item);
        await db.SaveChangesAsync();

        // Try to deliver immediately (fire-and-forget)
        if (attemptImmediately && fcmToken != null && recipientUserId.HasValue)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    var data = new Dictionary<string, string>
                    {
                        { "taskId", taskId?.ToString() ?? "" },
                        { "eventTime", item.EventOccurredAt.ToString("hh:mm tt") },
                        { "notificationId", item.Id.ToString() }
                    };
                    if (extraData != null) foreach (var kv in extraData) data[kv.Key] = kv.Value;

                    await _fcmService.SendPushNotificationAsync(
                        recipientUserId!.Value, fcmToken, title, body, data);

                    // Mark sent
                    using var s2 = _scopeFactory.CreateScope();
                    var db2 = s2.ServiceProvider.GetRequiredService<CoreDbContext>();
                    var queued = await db2.NotificationQueue.FindAsync(item.Id);
                    if (queued != null) { queued.Status = "SENT"; queued.SentAt = DateTime.UtcNow; }
                    await db2.SaveChangesAsync();
                }
                catch
                {
                    // Will be retried by NotificationRetryWorker
                }
            });
        }
    }
}
