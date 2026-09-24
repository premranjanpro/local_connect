using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("subscriptions")]
public class Subscription
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("customer_id")]
    public Guid CustomerId { get; set; }

    [Required]
    [Column("business_id")]
    public Guid BusinessId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("item_name")]
    public string ItemName { get; set; } = string.Empty;

    [Column("quantity", TypeName = "decimal(8,2)")]
    public decimal Quantity { get; set; } = 1.00m;

    [Required]
    [MaxLength(20)]
    [Column("unit")]
    public string Unit { get; set; } = "Litre";

    [Required]
    [MaxLength(50)]
    [Column("delivery_slot")]
    public string DeliverySlot { get; set; } = "06:00 - 07:30";

    [Required]
    [MaxLength(50)]
    [Column("days_of_week")]
    public string DaysOfWeek { get; set; } = "Everyday";

    [Column("price_per_delivery", TypeName = "decimal(10,2)")]
    public decimal PricePerDelivery { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(CustomerId))]
    public virtual User? Customer { get; set; }

    [ForeignKey(nameof(BusinessId))]
    public virtual Business? Business { get; set; }

    public virtual ICollection<SubscriptionPause> Pauses { get; set; } = new List<SubscriptionPause>();
    public virtual ICollection<SubscriptionDailyLog> DailyLogs { get; set; } = new List<SubscriptionDailyLog>();
}
