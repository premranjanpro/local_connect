using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("customer_rfqs")]
public class CustomerRfq
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("customer_id")]
    public Guid CustomerId { get; set; }

    [Required]
    [MaxLength(20)]
    [Column("mode")]
    public string Mode { get; set; } = "SingleShop"; // SingleShop, MultiShop, BroadcastNetwork

    [Column("raw_prompt")]
    public string RawPrompt { get; set; } = string.Empty;

    [Column("structured_items")]
    public string StructuredItems { get; set; } = "[]";

    [Column("delivery_latitude")]
    public double DeliveryLatitude { get; set; }

    [Column("delivery_longitude")]
    public double DeliveryLongitude { get; set; }

    [Required]
    [MaxLength(255)]
    [Column("delivery_address")]
    public string DeliveryAddress { get; set; } = string.Empty;

    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "Open";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("expires_at")]
    public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddMinutes(30);

    [ForeignKey(nameof(CustomerId))]
    public virtual User? Customer { get; set; }

    public virtual ICollection<RfqBusinessQuote> Quotes { get; set; } = new List<RfqBusinessQuote>();
}
