using System.Security.Claims;
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
[Route("api/v1/subscriptions")]
[Authorize]
public class SubscriptionsController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IAuditService _auditService;

    public SubscriptionsController(CoreDbContext dbContext, IAuditService auditService)
    {
        _dbContext = dbContext;
        _auditService = auditService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpPost]
    public async Task<IActionResult> CreateSubscription([FromBody] CreateSubscriptionRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var business = await _dbContext.Businesses.FindAsync(request.BusinessId);
        if (business == null) return NotFound(new { message = "Merchant shop not found." });

        var subscription = new Subscription
        {
            CustomerId = userId.Value,
            BusinessId = request.BusinessId,
            ItemName = request.ItemName,
            Quantity = request.Quantity,
            Unit = request.Unit,
            DeliverySlot = string.IsNullOrEmpty(request.DeliverySlot) ? "06:00 - 07:30" : request.DeliverySlot,
            DaysOfWeek = string.IsNullOrEmpty(request.DaysOfWeek) ? "Everyday" : request.DaysOfWeek,
            PricePerDelivery = request.PricePerDelivery,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.Subscriptions.Add(subscription);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "SubscriptionCreated",
            "Subscription",
            subscription.Id.ToString(),
            details: $"{{\"item\":\"{subscription.ItemName}\", \"quantity\":{subscription.Quantity}, \"slot\":\"{subscription.DeliverySlot}\"}}"
        );

        return Ok(subscription);
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMySubscriptions()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);

        var list = await _dbContext.Subscriptions
            .Include(s => s.Business)
            .Include(s => s.Pauses)
            .Where(s => s.CustomerId == userId.Value)
            .ToListAsync();

        return Ok(list.Select(s => new
        {
            s.Id,
            s.ItemName,
            s.Quantity,
            s.Unit,
            s.DeliverySlot,
            s.DaysOfWeek,
            s.PricePerDelivery,
            s.IsActive,
            BusinessName = s.Business?.Name,
            BusinessPhone = s.Business?.Phone,
            IsCurrentlyPaused = s.Pauses.Any(p => p.PauseStartDate <= today && p.PauseEndDate >= today),
            ActivePause = s.Pauses.FirstOrDefault(p => p.PauseStartDate <= today && p.PauseEndDate >= today)
        }));
    }

    [HttpPost("{id}/pause")]
    public async Task<IActionResult> PauseSubscription(Guid id, [FromBody] PauseSubscriptionRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var sub = await _dbContext.Subscriptions.FirstOrDefaultAsync(s => s.Id == id && s.CustomerId == userId.Value);
        if (sub == null) return NotFound();

        var pause = new SubscriptionPause
        {
            SubscriptionId = sub.Id,
            PauseStartDate = request.PauseStartDate,
            PauseEndDate = request.PauseEndDate,
            Reason = request.Reason ?? "Vacation Mode",
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.SubscriptionPauses.Add(pause);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "SubscriptionPausedVacationMode",
            "SubscriptionPause",
            pause.Id.ToString(),
            details: $"{{\"from\":\"{request.PauseStartDate}\", \"to\":\"{request.PauseEndDate}\", \"reason\":\"{pause.Reason}\"}}"
        );

        return Ok(new
        {
            message = $"Vacation mode activated. Deliveries paused from {request.PauseStartDate} to {request.PauseEndDate}.",
            pause
        });
    }

    [HttpPost("{id}/resume")]
    public async Task<IActionResult> ResumeSubscription(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);

        var activePauses = await _dbContext.SubscriptionPauses
            .Where(p => p.SubscriptionId == id && p.PauseEndDate >= today)
            .ToListAsync();

        _dbContext.SubscriptionPauses.RemoveRange(activePauses);
        await _dbContext.SaveChangesAsync();

        return Ok(new { message = "Vacation pause cancelled. Daily morning deliveries resumed." });
    }

    [HttpPost("run-daily-dispatch")]
    public async Task<IActionResult> RunDailyDispatch([FromQuery] DateOnly? targetDate)
    {
        var date = targetDate ?? DateOnly.FromDateTime(DateTime.UtcNow);

        // Fetch all active subscriptions
        var subs = await _dbContext.Subscriptions
            .Include(s => s.Business)
            .Include(s => s.Pauses)
            .Where(s => s.IsActive)
            .ToListAsync();

        int dispatchedCount = 0;
        int pausedCount = 0;

        foreach (var sub in subs)
        {
            // Check if customer is on vacation pause today
            bool isPaused = sub.Pauses.Any(p => p.PauseStartDate <= date && p.PauseEndDate >= date);

            var log = new SubscriptionDailyLog
            {
                SubscriptionId = sub.Id,
                DeliveryDate = date,
                Status = isPaused ? SubscriptionLogStatus.Paused.ToString() : SubscriptionLogStatus.Scheduled.ToString(),
                BilledAmount = isPaused ? 0.00m : sub.PricePerDelivery,
                CreatedAt = DateTime.UtcNow
            };

            _dbContext.SubscriptionDailyLogs.Add(log);

            if (isPaused)
            {
                pausedCount++;
            }
            else
            {
                dispatchedCount++;

                // Auto-sync into Khata ledger entries
                var ledger = new KhataLedgerEntry
                {
                    BusinessId = sub.BusinessId,
                    CustomerId = sub.CustomerId,
                    EntryType = KhataEntryType.DuesDebit.ToString(),
                    Amount = sub.PricePerDelivery,
                    PaymentMethod = KhataPaymentMethod.TaskDuesAdded.ToString(),
                    Notes = $"Daily Morning Run ({sub.ItemName} {sub.Quantity}{sub.Unit}) on {date}",
                    CreatedAt = DateTime.UtcNow
                };
                _dbContext.KhataLedgerEntries.Add(ledger);

                // Update customer dues
                var khataSetting = await _dbContext.KhataCustomerSettings
                    .FirstOrDefaultAsync(k => k.BusinessId == sub.BusinessId && k.CustomerId == sub.CustomerId);

                if (khataSetting != null)
                {
                    khataSetting.CurrentDues += sub.PricePerDelivery;
                    khataSetting.UpdatedAt = DateTime.UtcNow;
                }
            }
        }

        await _dbContext.SaveChangesAsync();

        return Ok(new
        {
            message = $"Daily morning dispatch for {date} executed.",
            dispatchedCount,
            pausedCount,
            totalSubscriptions = subs.Count
        });
    }
}
