using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

/// <summary>
/// Offline event batch — when driver has no internet, the Flutter app buffers
/// all task events (status changes, GPS pings, OTP verifications) in local
/// SQLite/Hive. When connectivity returns, the app flushes this batch to
/// POST /api/v1/tasks/offline-sync.
///
/// The server processes events in chronological order, applies state transitions,
/// logs GPS to telemetry DB, and dispatches pending notifications with
/// accurate event times.
/// </summary>
[Table("offline_event_batches")]
public class OfflineEventBatch
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("driver_id")]
    public Guid DriverId { get; set; }

    [Column("task_id")]
    public Guid? TaskId { get; set; }

    /// <summary>JSON array of OfflineEvent objects sorted by occurred_at</summary>
    [Required]
    [Column("events_json")]
    public string EventsJson { get; set; } = "[]";

    /// <summary>Total GPS points buffered in this batch</summary>
    [Column("gps_points_count")]
    public int GpsPointsCount { get; set; }

    /// <summary>When driver went offline</summary>
    [Column("offline_since")]
    public DateTime? OfflineSince { get; set; }

    /// <summary>When driver came back online and submitted this batch</summary>
    [Column("synced_at")]
    public DateTime SyncedAt { get; set; } = DateTime.UtcNow;

    /// <summary>PROCESSING | DONE | ERROR</summary>
    [MaxLength(12)]
    [Column("status")]
    public string Status { get; set; } = "PROCESSING";

    [Column("error_message")]
    [MaxLength(500)]
    public string? ErrorMessage { get; set; }

    /// <summary>Total km accumulated from offline GPS points</summary>
    [Column("total_km_offline", TypeName = "decimal(8,2)")]
    public decimal TotalKmOffline { get; set; }

    [ForeignKey(nameof(DriverId))]
    public virtual User? Driver { get; set; }
}
