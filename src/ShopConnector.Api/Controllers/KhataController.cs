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
[Route("api/v1/khata")]
[Authorize]
public class KhataController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IAuditService _auditService;

    public KhataController(CoreDbContext dbContext, IAuditService auditService)
    {
        _dbContext = dbContext;
        _auditService = auditService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    [HttpGet("{businessId}/customers/{customerId}")]
    public async Task<IActionResult> GetCustomerKhata(Guid businessId, Guid customerId)
    {
        var setting = await _dbContext.KhataCustomerSettings
            .Include(s => s.Customer)
            .FirstOrDefaultAsync(s => s.BusinessId == businessId && s.CustomerId == customerId);

        if (setting == null)
        {
            var business = await _dbContext.Businesses.FindAsync(businessId);
            return Ok(new
            {
                BusinessId = businessId,
                CustomerId = customerId,
                IsDuesAllowed = business?.DuesEnabledGlobally ?? false,
                CreditLimit = 0.00m,
                CurrentDues = 0.00m
            });
        }

        return Ok(new
        {
            setting.BusinessId,
            setting.CustomerId,
            setting.IsDuesAllowed,
            setting.CreditLimit,
            setting.CurrentDues,
            CustomerName = setting.Customer?.FullName,
            CustomerPhone = setting.Customer?.Phone
        });
    }

    [HttpPut("{businessId}/customers/{customerId}/permission")]
    public async Task<IActionResult> UpdateCustomerPermission(
        Guid businessId,
        Guid customerId,
        [FromBody] UpdateKhataPermissionRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var business = await _dbContext.Businesses.FirstOrDefaultAsync(b => b.Id == businessId && b.MerchantId == userId.Value);
        if (business == null) return NotFound(new { message = "Business not found or caller is not the owner merchant." });

        var setting = await _dbContext.KhataCustomerSettings
            .FirstOrDefaultAsync(s => s.BusinessId == businessId && s.CustomerId == customerId);

        if (setting == null)
        {
            setting = new KhataCustomerSetting
            {
                BusinessId = businessId,
                CustomerId = customerId,
                IsDuesAllowed = request.IsDuesAllowed,
                CreditLimit = request.CreditLimit,
                CurrentDues = 0.00m,
                UpdatedAt = DateTime.UtcNow
            };
            _dbContext.KhataCustomerSettings.Add(setting);
        }
        else
        {
            setting.IsDuesAllowed = request.IsDuesAllowed;
            setting.CreditLimit = request.CreditLimit;
            setting.UpdatedAt = DateTime.UtcNow;
        }

        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "KhataPermissionUpdated",
            "KhataCustomerSetting",
            setting.Id.ToString(),
            details: $"{{\"customerId\":\"{customerId}\", \"isDuesAllowed\":{request.IsDuesAllowed}, \"creditLimit\":{request.CreditLimit}}}"
        );

        return Ok(setting);
    }

    [HttpPost("transactions")]
    public async Task<IActionResult> RecordTransaction([FromBody] CreateKhataTransactionRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var setting = await _dbContext.KhataCustomerSettings
            .FirstOrDefaultAsync(s => s.BusinessId == request.BusinessId && s.CustomerId == request.CustomerId);

        if (setting == null)
        {
            setting = new KhataCustomerSetting
            {
                BusinessId = request.BusinessId,
                CustomerId = request.CustomerId,
                IsDuesAllowed = true,
                CreditLimit = 5000.00m,
                CurrentDues = 0.00m,
                UpdatedAt = DateTime.UtcNow
            };
            _dbContext.KhataCustomerSettings.Add(setting);
        }

        if (request.EntryType == KhataEntryType.DuesDebit)
        {
            // Adding dues (e.g. order placed on credit)
            setting.CurrentDues += request.Amount;
        }
        else if (request.EntryType == KhataEntryType.PaymentCredit)
        {
            // Payment made (doorstep cash collected by delivery boy or counter settlement)
            setting.CurrentDues = Math.Max(0.00m, setting.CurrentDues - request.Amount);
        }

        setting.UpdatedAt = DateTime.UtcNow;

        var entry = new KhataLedgerEntry
        {
            BusinessId = request.BusinessId,
            CustomerId = request.CustomerId,
            TaskId = request.TaskId,
            EntryType = request.EntryType.ToString(),
            Amount = request.Amount,
            PaymentMethod = request.PaymentMethod.ToString(),
            CollectedByUserId = userId.Value,
            Notes = request.Notes,
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.KhataLedgerEntries.Add(entry);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "KhataTransactionRecorded",
            "KhataLedgerEntry",
            entry.Id.ToString(),
            details: $"{{\"amount\":{request.Amount}, \"entryType\":\"{request.EntryType}\", \"paymentMethod\":\"{request.PaymentMethod}\", \"balanceDues\":{setting.CurrentDues}}}"
        );

        return Ok(new
        {
            entry.Id,
            entry.BusinessId,
            entry.CustomerId,
            entry.EntryType,
            entry.Amount,
            entry.PaymentMethod,
            entry.Notes,
            entry.CreatedAt,
            RemainingDues = setting.CurrentDues
        });
    }

    [HttpGet("{businessId}/ledger")]
    public async Task<IActionResult> GetLedger(
        Guid businessId,
        [FromQuery] Guid? customerId = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var query = _dbContext.KhataLedgerEntries
            .Include(l => l.Customer)
            .Include(l => l.CollectedByUser)
            .Where(l => l.BusinessId == businessId);

        if (customerId.HasValue)
        {
            query = query.Where(l => l.CustomerId == customerId.Value);
        }

        var total = await query.CountAsync();
        var items = await query
            .OrderByDescending(l => l.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(l => new
            {
                l.Id,
                l.BusinessId,
                l.CustomerId,
                CustomerName = l.Customer != null ? l.Customer.FullName : null,
                CustomerPhone = l.Customer != null ? l.Customer.Phone : null,
                l.TaskId,
                l.EntryType,
                l.Amount,
                l.PaymentMethod,
                CollectedByName = l.CollectedByUser != null ? l.CollectedByUser.FullName : null,
                l.Notes,
                l.CreatedAt
            })
            .ToListAsync();

        return Ok(new { Total = total, Page = page, PageSize = pageSize, Entries = items });
    }
}
