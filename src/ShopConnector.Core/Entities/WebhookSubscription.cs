using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// Webhook subscription — any actor (business, system) can register a URL
/// to receive POST callbacks for specific task events.
/// 
/// WhatsApp integration: Register webhook with wacrm-style payload format.
/// Event types: task.created, task.accepted, task.started, task.pickup_verified,
///              task.at_drop, task.completed, task.cancelled, task.geofence_alert
/// </summary>
[Table("webhook_subscriptions")]
public class WebhookSubscription
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Column("business_id")]
    public Guid? BusinessId { get; set; }

    [Column("user_id")]
    public Guid? UserId { get; set; }

    /// <summary>Target URL to POST webhook payload to</summary>
    [Required]
    [MaxLength(500)]
    [Column("endpoint_url")]
    public string EndpointUrl { get; set; } = string.Empty;

    /// <summary>Comma-separated event filters, e.g. "task.completed,task.geofence_alert"</summary>
    [MaxLength(500)]
    [Column("event_filter")]
    public string EventFilter { get; set; } = "*";

    /// <summary>Optional HMAC secret for payload signing (X-ShopConnector-Signature header)</summary>
    [MaxLength(100)]
    [Column("secret")]
    public string? Secret { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("last_fired_at")]
    public DateTime? LastFiredAt { get; set; }

    [Column("failure_count")]
    public int FailureCount { get; set; } = 0;

    [ForeignKey(nameof(BusinessId))]
    public virtual Business? Business { get; set; }
}
