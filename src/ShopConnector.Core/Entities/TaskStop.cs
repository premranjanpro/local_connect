using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// A TaskStop represents one pickup OR drop point within a multi-stop task.
///
/// Examples:
///   School run:    10 students × pickup (different) + 1 school (same drop)
///   Bulk grocery:  1 shop (pickup) + 10 customer addresses (different drops)
///   Multi-pickup:  3 shops (different pickups) + 1 customer (same drop)
///
/// Each stop has its own:
///   - OTP (pickup or drop)
///   - Geofence radius
///   - Status lifecycle
///   - Delivery log entries
///   - FCM/WhatsApp notification trigger on driver entry into geofence
/// </summary>
[Table("task_stops")]
public class TaskStop
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("task_id")]
    public Guid TaskId { get; set; }

    /// <summary>Stop sequence order (1, 2, 3...)</summary>
    [Column("stop_sequence")]
    public int StopSequence { get; set; }

    /// <summary>PICKUP or DROP</summary>
    [Required]
    [MaxLength(10)]
    [Column("stop_type")]
    public string StopType { get; set; } = "PICKUP"; // PICKUP | DROP

    [Required]
    [MaxLength(255)]
    [Column("address")]
    public string Address { get; set; } = string.Empty;

    [Column("latitude")]
    public double Latitude { get; set; }

    [Column("longitude")]
    public double Longitude { get; set; }

    /// <summary>Customer or student at this stop — for geofence-triggered notifications</summary>
    [Column("recipient_user_id")]
    public Guid? RecipientUserId { get; set; }

    /// <summary>Custom recipient name/label (e.g. "Rahul — Class 5B")</summary>
    [MaxLength(100)]
    [Column("recipient_label")]
    public string? RecipientLabel { get; set; }

    /// <summary>Phone for WhatsApp notification (may differ from UserId phone)</summary>
    [MaxLength(15)]
    [Column("recipient_phone")]
    public string? RecipientPhone { get; set; }

    // ── OTP ────────────────────────────────────────────────────────────────
    [Column("is_otp_required")]
    public bool IsOtpRequired { get; set; } = true;

    [MaxLength(6)]
    [Column("otp")]
    public string? Otp { get; set; }

    // ── Status ────────────────────────────────────────────────────────────
    /// <summary>PENDING → DRIVER_APPROACHING → ARRIVED → COMPLETED</summary>
    [MaxLength(25)]
    [Column("status")]
    public string Status { get; set; } = "PENDING";

    [Column("arrived_at")]
    public DateTime? ArrivedAt { get; set; }

    [Column("completed_at")]
    public DateTime? CompletedAt { get; set; }

    // ── Geofence ──────────────────────────────────────────────────────────
    /// <summary>Radius in meters that triggers DRIVER_APPROACHING notification</summary>
    [Column("geofence_radius_meters")]
    public int GeofenceRadiusMeters { get; set; } = 300;

    /// <summary>Has the "driver approaching" geofence notification already been sent?</summary>
    [Column("proximity_notified")]
    public bool ProximityNotified { get; set; } = false;

    [Column("proximity_notified_at")]
    public DateTime? ProximityNotifiedAt { get; set; }

    // ── Actual GPS at event ──────────────────────────────────────────────
    [Column("driver_lat_at_arrival")]
    public double? DriverLatAtArrival { get; set; }

    [Column("driver_lng_at_arrival")]
    public double? DriverLngAtArrival { get; set; }

    [Column("distance_from_stop_meters")]
    public double? DistanceFromStopMeters { get; set; }

    [MaxLength(10)]
    [Column("geofence_status")]
    public string GeofenceStatus { get; set; } = "N/A";

    // ── Notes ─────────────────────────────────────────────────────────────
    [MaxLength(255)]
    [Column("notes")]
    public string? Notes { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }

    [ForeignKey(nameof(RecipientUserId))]
    public virtual User? RecipientUser { get; set; }
}
