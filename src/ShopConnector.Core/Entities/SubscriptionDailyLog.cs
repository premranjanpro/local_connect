using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ShopConnector.Core.Enums;

namespace ShopConnector.Core.Entities;

[Table("subscription_daily_logs")]
public class SubscriptionDailyLog
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("subscription_id")]
    public Guid SubscriptionId { get; set; }

    [Column("delivery_date")]
    public DateOnly DeliveryDate { get; set; }

    [Column("task_id")]
    public Guid? TaskId { get; set; }

    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = SubscriptionLogStatus.Scheduled.ToString();

    [Column("billed_amount", TypeName = "decimal(10,2)")]
    public decimal BilledAmount { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(SubscriptionId))]
    public virtual Subscription? Subscription { get; set; }

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }
}
