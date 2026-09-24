using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("khata_customer_settings")]
public class KhataCustomerSetting
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("business_id")]
    public Guid BusinessId { get; set; }

    [Required]
    [Column("customer_id")]
    public Guid CustomerId { get; set; }

    [Column("is_dues_allowed")]
    public bool IsDuesAllowed { get; set; } = false;

    [Column("credit_limit", TypeName = "decimal(10,2)")]
    public decimal CreditLimit { get; set; } = 0.00m;

    [Column("current_dues", TypeName = "decimal(10,2)")]
    public decimal CurrentDues { get; set; } = 0.00m;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(BusinessId))]
    public virtual Business? Business { get; set; }

    [ForeignKey(nameof(CustomerId))]
    public virtual User? Customer { get; set; }
}
