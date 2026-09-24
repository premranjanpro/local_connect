using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("user_device_sessions")]
public class UserDeviceSession
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("user_id")]
    public Guid UserId { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("device_id")]
    public string DeviceId { get; set; } = string.Empty;

    [MaxLength(100)]
    [Column("device_model")]
    public string DeviceModel { get; set; } = string.Empty;

    [MaxLength(50)]
    [Column("os_version")]
    public string OsVersion { get; set; } = string.Empty;

    [MaxLength(20)]
    [Column("app_version")]
    public string AppVersion { get; set; } = string.Empty;

    [MaxLength(255)]
    [Column("fcm_token")]
    public string? FcmToken { get; set; }

    [MaxLength(50)]
    [Column("ip_address")]
    public string? IpAddress { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("logged_in_at")]
    public DateTime LoggedInAt { get; set; } = DateTime.UtcNow;

    [Column("last_active_at")]
    public DateTime LastActiveAt { get; set; } = DateTime.UtcNow;

    [Column("revoked_at")]
    public DateTime? RevokedAt { get; set; }

    [ForeignKey(nameof(UserId))]
    public virtual User? User { get; set; }
}
