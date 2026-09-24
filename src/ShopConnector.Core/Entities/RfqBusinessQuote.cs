using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ShopConnector.Core.Entities;

[Table("rfq_business_quotes")]
public class RfqBusinessQuote
{
    [Key]
    [Column("id")]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [Column("rfq_id")]
    public Guid RfqId { get; set; }

    [Required]
    [Column("business_id")]
    public Guid BusinessId { get; set; }

    [Column("quoted_total_price", TypeName = "decimal(10,2)")]
    public decimal QuotedTotalPrice { get; set; }

    [Column("quote_details")]
    public string QuoteDetails { get; set; } = "[]";

    [Column("estimated_prep_minutes")]
    public int EstimatedPrepMinutes { get; set; } = 15;

    [Required]
    [MaxLength(20)]
    [Column("status")]
    public string Status { get; set; } = "Offered"; // Offered, Accepted, Rejected, Expired

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(RfqId))]
    public virtual CustomerRfq? Rfq { get; set; }

    [ForeignKey(nameof(BusinessId))]
    public virtual Business? Business { get; set; }
}
