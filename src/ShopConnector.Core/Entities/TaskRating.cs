using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// Multi-party rating and review for an order/task:
/// - Driver rates Customer (behavior, punctuality, payment)
/// - Customer rates Driver (safety, on-time, vehicle)
/// - Customer rates Shop Owner (item quality, packaging, pricing)
/// </summary>
[Table("task_ratings")]
public class TaskRating
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("task_id")]
    public Guid TaskId { get; set; }

    [Required]
    [Column("from_user_id")]
    public Guid FromUserId { get; set; }

    /// <summary>Customer | Driver | Merchant</summary>
    [Required]
    [MaxLength(20)]
    [Column("from_role")]
    public string FromRole { get; set; } = string.Empty;

    [Column("to_user_id")]
    public Guid? ToUserId { get; set; }

    [Column("business_id")]
    public Guid? BusinessId { get; set; }

    /// <summary>Driver | Customer | Shop</summary>
    [Required]
    [MaxLength(20)]
    [Column("target_type")]
    public string TargetType { get; set; } = string.Empty;

    /// <summary>1 to 5 stars</summary>
    [Column("rating_stars")]
    public int RatingStars { get; set; }

    /// <summary>Comma-separated tags e.g. "Polite, On-Time, Clean Vehicle"</summary>
    [MaxLength(300)]
    [Column("feedback_tags")]
    public string? FeedbackTags { get; set; }

    [MaxLength(1000)]
    [Column("review_text")]
    public string? ReviewText { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }

    [ForeignKey(nameof(FromUserId))]
    public virtual User? FromUser { get; set; }

    [ForeignKey(nameof(ToUserId))]
    public virtual User? ToUser { get; set; }

    [ForeignKey(nameof(BusinessId))]
    public virtual Business? Business { get; set; }
}
