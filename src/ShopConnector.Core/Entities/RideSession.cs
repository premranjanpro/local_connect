using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// A RideSession groups multiple tasks/orders into a single driver ride.
///
/// Design philosophy:
///   Driver ONLY needs to press [▶ Start Ride] and [⏹ End Ride].
///   Everything else (geofence alerts, per-stop notifications) is automatic.
///   Driver MAY optionally mark individual stops, call customers, or
///   manually send "Get Ready" alerts — but none of it is mandatory.
///
/// Examples:
///   - School van: 10 students, driver starts ride, drops each child,
///     ends ride. Geofence alerts auto-fire as driver approaches each student.
///   - Bulk delivery: 1 pickup shop + 8 customer drops in one ride.
///   - Mixed: pickup A, pickup B, drop C, drop D in any order.
/// </summary>
[Table("ride_sessions")]
public class RideSession
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("driver_id")]
    public Guid DriverId { get; set; }

    /// <summary>Optional ride name set by dispatcher/shop owner e.g. "Morning School Run - Route 3"</summary>
    [MaxLength(100)]
    [Column("ride_name")]
    public string? RideName { get; set; }

    /// <summary>PENDING | ACTIVE | COMPLETED | CANCELLED</summary>
    [MaxLength(15)]
    [Column("status")]
    public string Status { get; set; } = "PENDING";

    [Column("started_at")]
    public DateTime? StartedAt { get; set; }

    [Column("ended_at")]
    public DateTime? EndedAt { get; set; }

    /// <summary>Total KM driven in this ride (accumulated from GPS pings)</summary>
    [Column("total_km", TypeName = "decimal(8,2)")]
    public decimal TotalKm { get; set; }

    /// <summary>Total minutes from start to end</summary>
    [Column("total_minutes")]
    public int TotalMinutes { get; set; }

    /// <summary>Driver's GPS at ride start</summary>
    [Column("start_lat")]
    public double? StartLat { get; set; }

    [Column("start_lng")]
    public double? StartLng { get; set; }

    /// <summary>Driver's GPS at ride end</summary>
    [Column("end_lat")]
    public double? EndLat { get; set; }

    [Column("end_lng")]
    public double? EndLng { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(DriverId))]
    public virtual User? Driver { get; set; }

    public virtual ICollection<RideTask> RideTasks { get; set; } = new List<RideTask>();
}

/// <summary>
/// Links a RideSession to one or more TaskEntities.
/// A single ride can include orders from different shops/customers.
/// Each RideTask optionally has a planned stop sequence.
/// </summary>
[Table("ride_tasks")]
public class RideTask
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Column("ride_session_id")]
    public Guid RideSessionId { get; set; }

    [Column("task_id")]
    public Guid TaskId { get; set; }

    /// <summary>Planned sequence in this ride (1 = first stop)</summary>
    [Column("planned_sequence")]
    public int PlannedSequence { get; set; }

    /// <summary>PENDING | PICKED_UP | DROPPED | SKIPPED</summary>
    [MaxLength(15)]
    [Column("status")]
    public string Status { get; set; } = "PENDING";

    [Column("picked_up_at")]
    public DateTime? PickedUpAt { get; set; }

    [Column("dropped_at")]
    public DateTime? DroppedAt { get; set; }

    /// <summary>
    /// Number of manual "Get Ready" alerts driver has sent to this task's recipient.
    /// Driver can send at most 3 manual alerts per task to prevent spam.
    /// </summary>
    [Column("manual_alert_count")]
    public int ManualAlertCount { get; set; }

    [Column("last_manual_alert_at")]
    public DateTime? LastManualAlertAt { get; set; }

    [ForeignKey(nameof(RideSessionId))]
    public virtual RideSession? RideSession { get; set; }

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }
}
