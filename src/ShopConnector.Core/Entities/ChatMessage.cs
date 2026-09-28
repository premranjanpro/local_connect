using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// Persisted chat message between any two parties on a task thread
/// (Customer ↔ Driver ↔ Shopkeeper).
/// </summary>
[Table("chat_messages")]
public class ChatMessage
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Task this message belongs to (nullable for direct DMs).</summary>
    [Column("task_id")]
    public Guid? TaskId { get; set; }

    /// <summary>Shared room / thread key, e.g. "task_{taskId}" or "dm_{userA}_{userB}".</summary>
    [Required]
    [MaxLength(100)]
    [Column("room_key")]
    public string RoomKey { get; set; } = string.Empty;

    [Required]
    [Column("sender_id")]
    public Guid SenderId { get; set; }

    [Required]
    [MaxLength(30)]
    [Column("sender_role")]
    public string SenderRole { get; set; } = "Customer"; // Customer | Driver | Merchant

    [Required]
    [Column("body")]
    public string Body { get; set; } = string.Empty;

    /// <summary>text | image | location | audio</summary>
    [MaxLength(20)]
    [Column("message_type")]
    public string MessageType { get; set; } = "text";

    /// <summary>Optional attachment URL (image, audio clip).</summary>
    [Column("attachment_url")]
    public string? AttachmentUrl { get; set; }

    [Column("is_read")]
    public bool IsRead { get; set; } = false;

    [Column("read_at")]
    public DateTime? ReadAt { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation
    [ForeignKey(nameof(SenderId))]
    public virtual User? Sender { get; set; }
}
