using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// Pending notification queue — stores notifications that could NOT be delivered
/// immediately (driver offline, FCM failure, WhatsApp API error).
///
/// A background retry worker flushes this table:
///   - Every 30 seconds for PENDING items
///   - Max 10 retries, then marks DEAD
///
/// When driver's app reconnects and syncs offline events, the server
/// re-dispatches any queued notifications with the ORIGINAL event time
/// clearly noted in the message: "Your order was picked up at 12:30 PM"
/// </summary>
[Table("notification_queue")]
public class NotificationQueueItem
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Column("task_id")]
    public Guid? TaskId { get; set; }

    [Column("task_stop_id")]
    public Guid? TaskStopId { get; set; }

    [Column("recipient_user_id")]
    public Guid? RecipientUserId { get; set; }

    /// <summary>Direct phone for WhatsApp (when no UserId)</summary>
    [MaxLength(15)]
    [Column("recipient_phone")]
    public string? RecipientPhone { get; set; }

    /// <summary>FCM token at time of queue</summary>
    [MaxLength(300)]
    [Column("fcm_token")]
    public string? FcmToken { get; set; }

    /// <summary>FCM | WHATSAPP | BOTH</summary>
    [MaxLength(10)]
    [Column("channel")]
    public string Channel { get; set; } = "FCM";

    [Required]
    [MaxLength(100)]
    [Column("title")]
    public string Title { get; set; } = string.Empty;

    [Required]
    [MaxLength(500)]
    [Column("body")]
    public string Body { get; set; } = string.Empty;

    /// <summary>JSON extra data for FCM data payload</summary>
    [Column("data_json")]
    public string? DataJson { get; set; }

    /// <summary>
    /// The ACTUAL time the event occurred (driver was offline).
    /// Used to say "Your order was picked up at 12:30" even if notification
    /// arrives at 1:15 after connectivity restored.
    /// </summary>
    [Column("event_occurred_at")]
    public DateTime EventOccurredAt { get; set; } = DateTime.UtcNow;

    /// <summary>PENDING | SENT | FAILED | DEAD</summary>
    [MaxLength(10)]
    [Column("status")]
    public string Status { get; set; } = "PENDING";

    [Column("retry_count")]
    public int RetryCount { get; set; } = 0;

    [Column("max_retries")]
    public int MaxRetries { get; set; } = 10;

    [Column("next_retry_at")]
    public DateTime? NextRetryAt { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("sent_at")]
    public DateTime? SentAt { get; set; }

    [Column("last_error")]
    [MaxLength(500)]
    public string? LastError { get; set; }

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }
}
