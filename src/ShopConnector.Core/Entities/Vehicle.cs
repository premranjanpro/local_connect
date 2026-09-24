using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("vehicles")]
public class Vehicle
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("driver_id")]
    public Guid DriverId { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("make")]
    public string Make { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    [Column("model")]
    public string Model { get; set; } = string.Empty;

    [Required]
    [MaxLength(20)]
    [Column("plate_number")]
    public string PlateNumber { get; set; } = string.Empty;

    [Required]
    [MaxLength(20)]
    [Column("vehicle_type")]
    public string VehicleType { get; set; } = string.Empty;

    [Column("is_verified")]
    public bool IsVerified { get; set; } = false;

    [Column("is_active")]
    public bool IsActive { get; set; } = false;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(DriverId))]
    public virtual User? Driver { get; set; }
}
