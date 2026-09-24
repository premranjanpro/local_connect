using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("school_transit_schedules")]
public class SchoolTransitSchedule
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("student_id")]
    public Guid StudentId { get; set; }

    [Required]
    [Column("guardian_id")]
    public Guid GuardianId { get; set; }

    [Column("driver_id")]
    public Guid? DriverId { get; set; }

    [Column("pickup_time")]
    public TimeSpan PickupTime { get; set; }

    [Column("pickup_latitude")]
    public double PickupLatitude { get; set; }

    [Column("pickup_longitude")]
    public double PickupLongitude { get; set; }

    [Column("school_latitude")]
    public double SchoolLatitude { get; set; }

    [Column("school_longitude")]
    public double SchoolLongitude { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("school_name")]
    public string SchoolName { get; set; } = string.Empty;

    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "Active";

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(StudentId))]
    public virtual User? Student { get; set; }

    [ForeignKey(nameof(GuardianId))]
    public virtual User? Guardian { get; set; }

    [ForeignKey(nameof(DriverId))]
    public virtual User? Driver { get; set; }
}
