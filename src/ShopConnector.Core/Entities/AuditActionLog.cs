using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("audit_action_logs")]
public class AuditActionLog
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Column("user_id")]
    public Guid? UserId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("action")]
    public string Action { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    [Column("entity_type")]
    public string EntityType { get; set; } = string.Empty;

    [Required]
    [MaxLength(50)]
    [Column("entity_id")]
    public string EntityId { get; set; } = string.Empty;

    [MaxLength(50)]
    [Column("ip_address")]
    public string? IpAddress { get; set; }

    [MaxLength(100)]
    [Column("device_id")]
    public string? DeviceId { get; set; }

    [Column("details")]
    public string? Details { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(UserId))]
    public virtual User? User { get; set; }
}
