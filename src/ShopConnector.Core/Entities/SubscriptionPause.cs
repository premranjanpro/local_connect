using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("subscription_pauses")]
public class SubscriptionPause
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("subscription_id")]
    public Guid SubscriptionId { get; set; }

    [Column("pause_start_date")]
    public DateOnly PauseStartDate { get; set; }

    [Column("pause_end_date")]
    public DateOnly PauseEndDate { get; set; }

    [MaxLength(100)]
    [Column("reason")]
    public string? Reason { get; set; } = "Vacation";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(SubscriptionId))]
    public virtual Subscription? Subscription { get; set; }
}
