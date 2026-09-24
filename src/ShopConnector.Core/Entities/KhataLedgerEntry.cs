using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using ShopConnector.Core.Enums;

namespace ShopConnector.Core.Entities;

[Table("khata_ledger_entries")]
public class KhataLedgerEntry
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

    [Column("task_id")]
    public Guid? TaskId { get; set; }

    [Required]
    [MaxLength(20)]
    [Column("entry_type")]
    public string EntryType { get; set; } = KhataEntryType.DuesDebit.ToString(); // DuesDebit, PaymentCredit

    [Column("amount", TypeName = "decimal(10,2)")]
    public decimal Amount { get; set; }

    [Required]
    [MaxLength(30)]
    [Column("payment_method")]
    public string PaymentMethod { get; set; } = KhataPaymentMethod.DoorstepCashToDeliveryBoy.ToString();

    [Column("collected_by_user_id")]
    public Guid? CollectedByUserId { get; set; }

    [MaxLength(255)]
    [Column("notes")]
    public string? Notes { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(BusinessId))]
    public virtual Business? Business { get; set; }

    [ForeignKey(nameof(CustomerId))]
    public virtual User? Customer { get; set; }

    [ForeignKey(nameof(TaskId))]
    public virtual TaskEntity? Task { get; set; }

    [ForeignKey(nameof(CollectedByUserId))]
    public virtual User? CollectedByUser { get; set; }
}
