using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.DTOs;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Enums;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1/rfq")]
[Authorize]
public class CustomerRfqController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IDistanceMatrixService _distanceMatrixService;
    private readonly IAuditService _auditService;

    public CustomerRfqController(
        CoreDbContext dbContext,
        IDistanceMatrixService distanceMatrixService,
        IAuditService auditService)
    {
        _dbContext = dbContext;
        _distanceMatrixService = distanceMatrixService;
        _auditService = auditService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpPost]
    public async Task<IActionResult> CreateRfq([FromBody] CreateRfqRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var rfq = new CustomerRfq
        {
            CustomerId = userId.Value,
            Mode = request.Mode.ToString(),
            RawPrompt = request.RawPrompt,
            StructuredItems = request.StructuredItemsJson ?? "[]",
            DeliveryLatitude = request.DeliveryLatitude,
            DeliveryLongitude = request.DeliveryLongitude,
            DeliveryAddress = request.DeliveryAddress,
            Status = RfqStatus.Open.ToString(),
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddMinutes(30)
        };

        _dbContext.CustomerRfqs.Add(rfq);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "RfqCreated",
            "CustomerRfq",
            rfq.Id.ToString(),
            details: $"{{\"mode\":\"{rfq.Mode}\", \"prompt\":\"{rfq.RawPrompt}\"}}"
        );

        return Ok(rfq);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetRfq(Guid id)
    {
        var rfq = await _dbContext.CustomerRfqs
            .Include(r => r.Customer)
            .Include(r => r.Quotes)
                .ThenInclude(q => q.Business)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (rfq == null) return NotFound();

        return Ok(new
        {
            rfq.Id,
            rfq.CustomerId,
            CustomerName = rfq.Customer?.FullName,
            rfq.Mode,
            rfq.RawPrompt,
            rfq.StructuredItems,
            rfq.DeliveryAddress,
            rfq.DeliveryLatitude,
            rfq.DeliveryLongitude,
            rfq.Status,
            rfq.CreatedAt,
            rfq.ExpiresAt,
            Quotes = rfq.Quotes.Select(q => new
            {
                q.Id,
                q.BusinessId,
                BusinessName = q.Business?.Name,
                BusinessPhone = q.Business?.Phone,
                q.QuotedTotalPrice,
                q.QuoteDetails,
                q.EstimatedPrepMinutes,
                q.Status,
                q.CreatedAt
            })
        });
    }

    [HttpPost("{id}/quote")]
    public async Task<IActionResult> SubmitQuote(Guid id, [FromQuery] Guid businessId, [FromBody] SubmitQuoteRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var business = await _dbContext.Businesses.FirstOrDefaultAsync(b => b.Id == businessId && b.MerchantId == userId.Value);
        if (business == null) return NotFound(new { message = "Merchant shop not found or caller is not authorized." });

        var rfq = await _dbContext.CustomerRfqs.FindAsync(id);
        if (rfq == null) return NotFound(new { message = "RFQ not found." });

        if (rfq.Status != RfqStatus.Open.ToString() && rfq.Status != RfqStatus.QuotesReceived.ToString())
        {
            return BadRequest(new { message = "RFQ is no longer open for quotes." });
        }

        var quote = new RfqBusinessQuote
        {
            RfqId = id,
            BusinessId = businessId,
            QuotedTotalPrice = request.QuotedTotalPrice,
            QuoteDetails = request.QuoteDetailsJson ?? "[]",
            EstimatedPrepMinutes = request.EstimatedPrepMinutes,
            Status = RfqQuoteStatus.Offered.ToString(),
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.RfqBusinessQuotes.Add(quote);
        rfq.Status = RfqStatus.QuotesReceived.ToString();

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "RfqQuoteSubmitted",
            "RfqBusinessQuote",
            quote.Id.ToString(),
            details: $"{{\"rfqId\":\"{id}\", \"price\":{quote.QuotedTotalPrice}}}"
        );

        return Ok(quote);
    }

    [HttpPost("{id}/quotes/{quoteId}/accept")]
    public async Task<IActionResult> AcceptQuote(Guid id, Guid quoteId, [FromQuery] PaymentMode paymentMode = PaymentMode.Cash)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var rfq = await _dbContext.CustomerRfqs
            .Include(r => r.Quotes)
            .FirstOrDefaultAsync(r => r.Id == id && r.CustomerId == userId.Value);

        if (rfq == null) return NotFound(new { message = "RFQ not found or caller is not the owner." });

        var winningQuote = rfq.Quotes.FirstOrDefault(q => q.Id == quoteId);
        if (winningQuote == null) return NotFound(new { message = "Quote not found." });

        var business = await _dbContext.Businesses.FindAsync(winningQuote.BusinessId);
        if (business == null) return NotFound(new { message = "Winning business not found." });

        // Mark winning quote and reject others
        foreach (var q in rfq.Quotes)
        {
            q.Status = q.Id == quoteId ? RfqQuoteStatus.Accepted.ToString() : RfqQuoteStatus.Rejected.ToString();
        }
        rfq.Status = RfqStatus.Accepted.ToString();

        // Calculate delivery distance from business to customer
        var dist = await _distanceMatrixService.CalculateDistanceAsync(
            business.Latitude,
            business.Longitude,
            rfq.DeliveryLatitude,
            rfq.DeliveryLongitude
        );

        // Auto-create task for grocery delivery!
        var pickupOtp = RandomNumberGenerator.GetInt32(100000, 999999).ToString();
        var dropoffOtp = RandomNumberGenerator.GetInt32(100000, 999999).ToString();

        var task = new TaskEntity
        {
            CustomerId = userId.Value,
            BusinessId = winningQuote.BusinessId,
            TaskType = TaskType.GroceryDelivery.ToString(),
            Status = PlatformTaskStatus.Broadcasting.ToString(),
            PickupAddress = business.Address,
            PickupLatitude = business.Latitude,
            PickupLongitude = business.Longitude,
            DropoffAddress = rfq.DeliveryAddress,
            DropoffLatitude = rfq.DeliveryLatitude,
            DropoffLongitude = rfq.DeliveryLongitude,
            PickupOtp = pickupOtp,
            DropoffOtp = dropoffOtp,
            DistanceKm = dist.DistanceKm,
            DurationMinutes = dist.DurationMinutes,
            FareAmount = winningQuote.QuotedTotalPrice + Math.Round(25.00m + (dist.DistanceKm * 10.00m), 2),
            PaymentMode = paymentMode.ToString(),
            PaymentStatus = PaymentStatus.Pending.ToString(),
            OrderItems = winningQuote.QuoteDetails,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Tasks.Add(task);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "RfqQuoteAcceptedAndTaskCreated",
            "TaskEntity",
            task.Id.ToString(),
            details: $"{{\"quoteId\":\"{quoteId}\", \"businessId\":\"{winningQuote.BusinessId}\"}}"
        );

        return Ok(new
        {
            message = "Quote accepted! Grocery delivery task dispatched.",
            rfqId = rfq.Id,
            quoteId = winningQuote.Id,
            dispatchedTaskId = task.Id
        });
    }
}
