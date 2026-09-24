using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("businesses")]
public class Business
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("merchant_id")]
    public Guid MerchantId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("name")]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    [Column("category")]
    public string Category { get; set; } = string.Empty;

    [Required]
    [MaxLength(15)]
    [Column("phone")]
    public string Phone { get; set; } = string.Empty;

    [Required]
    [MaxLength(255)]
    [Column("address")]
    public string Address { get; set; } = string.Empty;

    [Column("latitude")]
    public double Latitude { get; set; }

    [Column("longitude")]
    public double Longitude { get; set; }

    [Column("open_time")]
    public TimeSpan OpenTime { get; set; } = new TimeSpan(8, 0, 0);

    [Column("close_time")]
    public TimeSpan CloseTime { get; set; } = new TimeSpan(22, 0, 0);

    [Column("is_open")]
    public bool IsOpen { get; set; } = true;

    [Column("dues_enabled_globally")]
    public bool DuesEnabledGlobally { get; set; } = true;

    [MaxLength(100)]
    [Column("allowed_payment_modes")]
    public string AllowedPaymentModes { get; set; } = "Cash,Online,Dues";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(MerchantId))]
    public virtual User? Merchant { get; set; }

    public virtual ICollection<CatalogItem> CatalogItems { get; set; } = new List<CatalogItem>();
}
