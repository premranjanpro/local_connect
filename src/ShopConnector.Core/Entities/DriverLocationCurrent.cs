using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("driver_location_current")]
public class DriverLocationCurrent
{
    [Key]
    [Column("driver_id")]
    public Guid DriverId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("device_id")]
    public string DeviceId { get; set; } = string.Empty;

    [Column("latitude")]
    public double Latitude { get; set; }

    [Column("longitude")]
    public double Longitude { get; set; }

    [Column("heading")]
    public double Heading { get; set; }

    [Column("speed")]
    public double Speed { get; set; }

    [Required]
    [MaxLength(30)]
    [Column("duty_status")]
    public string DutyStatus { get; set; } = "Free";

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
