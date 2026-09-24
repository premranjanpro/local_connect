using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ShopConnector.Core.Enums;

namespace ShopConnector.Core.Entities;

[Table("driver_profiles")]
public class DriverProfile
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Column("active_vehicle_id")]
    public Guid? ActiveVehicleId { get; set; }

    [MaxLength(50)]
    [Column("license_number")]
    public string LicenseNumber { get; set; } = string.Empty;

    [Required]
    [MaxLength(30)]
    [Column("duty_status")]
    public string DutyStatus { get; set; } = DriverDutyStatus.OffDuty.ToString();

    [Column("acceptance_radius_km", TypeName = "decimal(5,2)")]
    public decimal AcceptanceRadiusKm { get; set; } = 1.00m;

    [Column("delivery_radius_km", TypeName = "decimal(5,2)")]
    public decimal DeliveryRadiusKm { get; set; } = 10.00m;

    [Column("current_latitude")]
    public double? CurrentLatitude { get; set; }

    [Column("current_longitude")]
    public double? CurrentLongitude { get; set; }

    [Column("current_heading")]
    public double? CurrentHeading { get; set; }

    [Column("current_speed")]
    public double? CurrentSpeed { get; set; }

    [Column("battery_pct")]
    public int? BatteryPct { get; set; }

    [Column("is_charging")]
    public bool? IsCharging { get; set; }

    [Column("last_heartbeat_at")]
    public DateTime? LastHeartbeatAt { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(UserId))]
    public virtual User? User { get; set; }

    [ForeignKey(nameof(ActiveVehicleId))]
    public virtual Vehicle? ActiveVehicle { get; set; }
}
