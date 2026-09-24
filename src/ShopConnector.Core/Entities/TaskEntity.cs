using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ShopConnector.Core.Enums;

namespace ShopConnector.Core.Entities;

[Table("tasks")]
public class TaskEntity
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("customer_id")]
    public Guid CustomerId { get; set; }

    [Column("business_id")]
    public Guid? BusinessId { get; set; }

    [Column("assigned_driver_id")]
    public Guid? AssignedDriverId { get; set; }

    [Required]
    [MaxLength(30)]
    [Column("task_type")]
    public string TaskType { get; set; } = Enums.TaskType.MobilityRide.ToString();

    [Required]
    [MaxLength(30)]
    [Column("status")]
    public string Status { get; set; } = Enums.PlatformTaskStatus.Created.ToString();

    [Required]
    [MaxLength(255)]
    [Column("pickup_address")]
    public string PickupAddress { get; set; } = string.Empty;

    [Column("pickup_latitude")]
    public double PickupLatitude { get; set; }

    [Column("pickup_longitude")]
    public double PickupLongitude { get; set; }

    [Required]
    [MaxLength(255)]
    [Column("dropoff_address")]
    public string DropoffAddress { get; set; } = string.Empty;

    [Column("dropoff_latitude")]
    public double DropoffLatitude { get; set; }

    [Column("dropoff_longitude")]
    public double DropoffLongitude { get; set; }

    [Required]
    [MaxLength(6)]
    [Column("pickup_otp")]
    public string PickupOtp { get; set; } = string.Empty;

    [Required]
    [MaxLength(6)]
    [Column("dropoff_otp")]
    public string DropoffOtp { get; set; } = string.Empty;

    [Column("distance_km", TypeName = "decimal(8,2)")]
    public decimal DistanceKm { get; set; }

    [Column("duration_minutes")]
    public int DurationMinutes { get; set; }

    [Column("fare_amount", TypeName = "decimal(10,2)")]
    public decimal FareAmount { get; set; }

    [Required]
    [MaxLength(20)]
    [Column("payment_mode")]
    public string PaymentMode { get; set; } = Enums.PaymentMode.Cash.ToString();

    [Required]
    [MaxLength(20)]
    [Column("payment_status")]
    public string PaymentStatus { get; set; } = Enums.PaymentStatus.Pending.ToString();

    [Column("order_items")]
    public string? OrderItems { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("accepted_at")]
    public DateTime? AcceptedAt { get; set; }

    [Column("completed_at")]
    public DateTime? CompletedAt { get; set; }

    [ForeignKey(nameof(CustomerId))]
    public virtual User? Customer { get; set; }

    [ForeignKey(nameof(BusinessId))]
    public virtual Business? Business { get; set; }

    [ForeignKey(nameof(AssignedDriverId))]
    public virtual User? AssignedDriver { get; set; }

    public virtual ICollection<TaskAssignment> Assignments { get; set; } = new List<TaskAssignment>();
}
