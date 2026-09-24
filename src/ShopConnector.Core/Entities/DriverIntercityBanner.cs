using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("driver_intercity_banners")]
public class DriverIntercityBanner
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("driver_id")]
    public Guid DriverId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("from_city")]
    public string FromCity { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    [Column("to_city")]
    public string ToCity { get; set; } = string.Empty;

    [Column("departure_time")]
    public DateTime DepartureTime { get; set; }

    [Column("seats_available")]
    public int SeatsAvailable { get; set; } = 1;

    [Column("expected_price", TypeName = "decimal(10,2)")]
    public decimal ExpectedPrice { get; set; }

    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "Active";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(DriverId))]
    public virtual User? Driver { get; set; }
}
