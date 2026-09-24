using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ShopConnector.Core.Enums;

namespace ShopConnector.Core.Entities;

[Table("task_assignments")]
public class TaskAssignment
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

    [Required]
    [MaxLength(100)]
    [Column("device_id")]
    public string DeviceId { get; set; } = string.Empty;

    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = TaskAssignmentStatus.Offered.ToString();

    [Column("offered_at")]
    public DateTime OfferedAt { get; set; } = DateTime.UtcNow;

    [Column("responded_at")]
    public DateTime? RespondedAt { get; set; }

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }

    [ForeignKey(nameof(DriverId))]
    public virtual User? Driver { get; set; }
}
