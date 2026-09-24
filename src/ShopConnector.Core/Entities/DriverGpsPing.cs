using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("driver_gps_pings")]
public class DriverGpsPing
{
    [Key]
    [Column("id")]
    public long Id { get; set; }

    [Required]
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

    [Column("altitude")]
    public double? Altitude { get; set; }

    [Column("heading")]
    public double Heading { get; set; }

    [Column("speed")]
    public double Speed { get; set; }

    [Column("accuracy")]
    public double Accuracy { get; set; }

    [Column("battery_pct")]
    public int BatteryPct { get; set; }

    [Column("is_charging")]
    public bool IsCharging { get; set; }

    [Column("timestamp")]
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
}
