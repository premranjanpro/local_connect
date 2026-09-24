using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ShopConnector.Core.Enums;

namespace ShopConnector.Core.Entities;

[Table("message_dispatch_logs")]
public class MessageDispatchLog
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Column("recipient_user_id")]
    public Guid? RecipientUserId { get; set; }

    [Required]
    [MaxLength(20)]
    [Column("channel")]
    public string Channel { get; set; } = MessageChannel.PushNotification.ToString(); // Email, SMS, WhatsApp, PushNotification

    [Required]
    [MaxLength(100)]
    [Column("recipient_address")]
    public string RecipientAddress { get; set; } = string.Empty;

    [MaxLength(200)]
    [Column("subject_or_title")]
    public string? SubjectOrTitle { get; set; }

    [Column("body")]
    public string Body { get; set; } = string.Empty;

    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "Sent"; // Queued, Sent, Failed

    [Column("error_message")]
    public string? ErrorMessage { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(RecipientUserId))]
    public virtual User? RecipientUser { get; set; }
}
