using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("customer_addresses")]
public class CustomerAddress
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Required]
    [MaxLength(30)]
    [Column("address_type")] // "Home", "Office", "Other"
    public string AddressType { get; set; } = "Home";

    [Required]
    [MaxLength(100)]
    [Column("title")] // e.g. "My Home", "Work Office", "Mom's Place"
    public string Title { get; set; } = string.Empty;

    [Required]
    [MaxLength(300)]
    [Column("full_address")]
    public string FullAddress { get; set; } = string.Empty;

    [MaxLength(100)]
    [Column("landmark")]
    public string? Landmark { get; set; }

    [Column("latitude")]
    public double? Latitude { get; set; }

    [Column("longitude")]
    public double? Longitude { get; set; }

    [Column("is_default")]
    public bool IsDefault { get; set; } = false;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(UserId))]
    public virtual User? User { get; set; }
}
