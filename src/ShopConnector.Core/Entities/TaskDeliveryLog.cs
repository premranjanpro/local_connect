using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// Immutable delivery event log — every status transition is permanently recorded
/// with exact GPS coordinates and geofence validation result.
/// This table is the legal audit trail for every delivery.
/// </summary>
[Table("task_delivery_logs")]
public class TaskDeliveryLog
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("task_id")]
    public Guid TaskId { get; set; }

    [Required]
    [Column("driver_id")]
    public Guid DriverId { get; set; }

    /// <summary>Event type: TaskStarted, ArrivedPickup, PickedUp, ArrivedDrop, Delivered, MarketPosted, etc.</summary>
    [Required]
    [MaxLength(50)]
    [Column("event_type")]
    public string EventType { get; set; } = string.Empty;

    /// <summary>Status BEFORE this event</summary>
    [MaxLength(30)]
    [Column("from_status")]
    public string? FromStatus { get; set; }

    /// <summary>Status AFTER this event</summary>
    [Required]
    [MaxLength(30)]
    [Column("to_status")]
    public string ToStatus { get; set; } = string.Empty;

    /// <summary>Driver's actual GPS lat at event time</summary>
    [Column("driver_lat")]
    public double? DriverLat { get; set; }

    /// <summary>Driver's actual GPS lng at event time</summary>
    [Column("driver_lng")]
    public double? DriverLng { get; set; }

    /// <summary>Expected location lat (pickup or dropoff point)</summary>
    [Column("expected_lat")]
    public double? ExpectedLat { get; set; }

    /// <summary>Expected location lng</summary>
    [Column("expected_lng")]
    public double? ExpectedLng { get; set; }

    /// <summary>Haversine distance (meters) between driver and expected point</summary>
    [Column("distance_from_expected_meters")]
    public double? DistanceFromExpectedMeters { get; set; }

    /// <summary>
    /// GeofenceStatus:
    ///   OK       = driver within 150m of expected point
    ///   WARNING  = 150-400m  (yellow alert)
    ///   ALERT    = 400m+     (red alert — notify shop owner)
    ///   N/A      = no geofence check applicable
    /// </summary>
    [MaxLength(10)]
    [Column("geofence_status")]
    public string GeofenceStatus { get; set; } = "N/A";

    /// <summary>Device ID that submitted this event</summary>
    [MaxLength(100)]
    [Column("device_id")]
    public string? DeviceId { get; set; }

    [Column("occurred_at")]
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;

    [Column("notes")]
    public string? Notes { get; set; }

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }

    [ForeignKey(nameof(DriverId))]
    public virtual User? Driver { get; set; }
}
