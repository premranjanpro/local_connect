using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Enums;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Services.Workers;

/// <summary>
/// SubscriptionDispatchWorker — Morning Auto-Dispatch Cron Service
///
/// Schedule: Runs every day at 04:30 AM UTC (≈ 10:00 AM IST).
/// Logic:
///   1. Fetches all active subscriptions for today.
///   2. Skips any subscriptions where the customer has a vacation pause covering today.
///   3. Creates SubscriptionDailyLog records (Scheduled or Paused, billed at ₹0).
///   4. Syncs billed amounts to the KhataLedger (digital Udhar account) for each shop.
///   5. On 1st of every month: runs the month-end consolidated Khata sync.
///
/// This is a pure .NET HostedService — no Docker, no Quartz, no Hangfire.
/// Uses a simple 24h timer loop with persisted "last-run" tracking.
/// </summary>
public class SubscriptionDispatchWorker : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<SubscriptionDispatchWorker> _logger;
    private readonly IConfiguration _config;

    // How long to wait between execution checks (every 5 minutes,
    // the worker wakes up and decides if it needs to act)
    private static readonly TimeSpan CheckInterval = TimeSpan.FromMinutes(5);

    public SubscriptionDispatchWorker(
        IServiceScopeFactory scopeFactory,
        ILogger<SubscriptionDispatchWorker> logger,
        IConfiguration config)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
        _config = config;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("[DispatchWorker] Morning Subscription Auto-Dispatch Worker started.");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await TryRunDispatchIfDueAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[DispatchWorker] Unhandled error in dispatch loop.");
            }

            // Wake up every 5 minutes to re-evaluate
            await Task.Delay(CheckInterval, stoppingToken);
        }

        _logger.LogInformation("[DispatchWorker] Morning Subscription Auto-Dispatch Worker stopped.");
    }

    private async Task TryRunDispatchIfDueAsync(CancellationToken ct)
    {
        // IST = UTC + 5:30. Target fire time: 04:30 AM UTC = 10:00 AM IST
        var nowUtc = DateTime.UtcNow;
        var targetHourUtc = _config.GetValue<int>("SubscriptionDispatch:FireHourUtc", 0); // default 00:30 UTC (06:00 AM IST)
        var targetMinuteUtc = _config.GetValue<int>("SubscriptionDispatch:FireMinuteUtc", 30);
        var todayDate = DateOnly.FromDateTime(nowUtc);

        // Check if we're within the 5-minute execution window
        bool isWithinWindow =
            nowUtc.Hour == targetHourUtc &&
            nowUtc.Minute >= targetMinuteUtc &&
            nowUtc.Minute < targetMinuteUtc + 5;

        if (!isWithinWindow) return;

        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CoreDbContext>();

        // Idempotency check: Has today's dispatch already run?
        bool alreadyRanToday = await db.SubscriptionDailyLogs
            .AnyAsync(l => l.DeliveryDate == todayDate, ct);

        if (alreadyRanToday)
        {
            _logger.LogDebug("[DispatchWorker] Today's dispatch ({Date}) already completed. Skipping.", todayDate);
            return;
        }

        _logger.LogInformation("[DispatchWorker] Starting morning dispatch for {Date}...", todayDate);

        await RunDailyDispatchAsync(db, todayDate, ct);

        // On 1st of every month, run the month-end Khata consolidation
        if (nowUtc.Day == 1)
        {
            var lastMonthDate = DateOnly.FromDateTime(nowUtc.AddMonths(-1));
            await RunMonthEndKhataConsolidationAsync(db, lastMonthDate, ct);
        }
    }

    // ── Core Daily Dispatch Logic ─────────────────────────────────────────

    public async Task RunDailyDispatchAsync(CoreDbContext db, DateOnly date, CancellationToken ct = default)
    {
        // Load all active subscriptions with pauses and business info
        var subs = await db.Subscriptions
            .Include(s => s.Business)
            .Include(s => s.Pauses)
            .Include(s => s.Customer)
            .Where(s => s.IsActive)
            .ToListAsync(ct);

        _logger.LogInformation("[DispatchWorker] Found {Count} active subscriptions for {Date}.", subs.Count, date);

        int dispatched = 0, paused = 0, skipped = 0;

        foreach (var sub in subs)
        {
            // Filter by DaysOfWeek (e.g., "Everyday", "Mon,Wed,Fri", "Weekdays")
            if (!IsDeliveryDueToday(sub.DaysOfWeek, date))
            {
                skipped++;
                continue;
            }

            bool isPaused = sub.Pauses.Any(p => p.PauseStartDate <= date && p.PauseEndDate >= date);

            var log = new SubscriptionDailyLog
            {
                SubscriptionId = sub.Id,
                DeliveryDate = date,
                Status = isPaused
                    ? SubscriptionLogStatus.Paused.ToString()
                    : SubscriptionLogStatus.Scheduled.ToString(),
                BilledAmount = isPaused ? 0.00m : sub.PricePerDelivery,
                CreatedAt = DateTime.UtcNow
            };

            db.SubscriptionDailyLogs.Add(log);

            if (isPaused)
            {
                paused++;
                _logger.LogDebug("[DispatchWorker] Sub {SubId} PAUSED for {Customer}.", sub.Id, sub.Customer?.FullName);
                continue;
            }

            // Debit the Khata ledger
            var ledgerEntry = new KhataLedgerEntry
            {
                BusinessId = sub.BusinessId,
                CustomerId = sub.CustomerId,
                EntryType = KhataEntryType.DuesDebit.ToString(),
                Amount = sub.PricePerDelivery,
                PaymentMethod = KhataPaymentMethod.TaskDuesAdded.ToString(),
                Notes = $"Auto Morning Dispatch: {sub.ItemName} {sub.Quantity}{sub.Unit} | {date:dd MMM yyyy}",
                CreatedAt = DateTime.UtcNow
            };
            db.KhataLedgerEntries.Add(ledgerEntry);

            // Update running dues balance on KhataCustomerSetting
            var khataSetting = await db.KhataCustomerSettings
                .FirstOrDefaultAsync(k => k.BusinessId == sub.BusinessId && k.CustomerId == sub.CustomerId, ct);

            if (khataSetting != null)
            {
                khataSetting.CurrentDues += sub.PricePerDelivery;
                khataSetting.UpdatedAt = DateTime.UtcNow;
            }

            dispatched++;
        }

        await db.SaveChangesAsync(ct);

        _logger.LogInformation(
            "[DispatchWorker] Daily dispatch for {Date} complete — Dispatched: {D}, Paused: {P}, Skipped (wrong day): {S}.",
            date, dispatched, paused, skipped);
    }

    // ── Month-End Khata Consolidation ─────────────────────────────────────

    private async Task RunMonthEndKhataConsolidationAsync(CoreDbContext db, DateOnly month, CancellationToken ct)
    {
        _logger.LogInformation("[DispatchWorker] Running month-end Khata consolidation for {Month:MMM yyyy}.", month.ToDateTime(TimeOnly.MinValue));

        var monthStart = new DateOnly(month.Year, month.Month, 1);
        var monthEnd = monthStart.AddMonths(1).AddDays(-1);

        // Group all delivered (non-paused) logs by business + customer
        var deliveredLogs = await db.SubscriptionDailyLogs
            .Include(l => l.Subscription)
            .Where(l => l.DeliveryDate >= monthStart &&
                        l.DeliveryDate <= monthEnd &&
                        l.Status == SubscriptionLogStatus.Scheduled.ToString())
            .ToListAsync(ct);

        var grouped = deliveredLogs
            .GroupBy(l => new { l.Subscription!.BusinessId, l.Subscription.CustomerId });

        int consolidations = 0;
        foreach (var grp in grouped)
        {
            decimal totalBilled = grp.Sum(l => l.BilledAmount);
            int deliveredDays = grp.Count();
            int pausedDays = await db.SubscriptionDailyLogs
                .CountAsync(l =>
                    l.Subscription!.BusinessId == grp.Key.BusinessId &&
                    l.Subscription.CustomerId == grp.Key.CustomerId &&
                    l.DeliveryDate >= monthStart &&
                    l.DeliveryDate <= monthEnd &&
                    l.Status == SubscriptionLogStatus.Paused.ToString(), ct);

            // Add a month-end consolidated summary entry in the Khata
            var consolidatedEntry = new KhataLedgerEntry
            {
                BusinessId = grp.Key.BusinessId,
                CustomerId = grp.Key.CustomerId,
                EntryType = KhataEntryType.DuesDebit.ToString(),
                Amount = 0, // Individual daily entries already captured the amounts
                PaymentMethod = KhataPaymentMethod.TaskDuesAdded.ToString(),
                Notes = $"[MONTH-END STATEMENT] {month:MMM yyyy}: {deliveredDays} deliveries ✓, {pausedDays} vacation days ₹0. Total due: ₹{totalBilled:F2}",
                CreatedAt = DateTime.UtcNow
            };
            db.KhataLedgerEntries.Add(consolidatedEntry);
            consolidations++;
        }

        await db.SaveChangesAsync(ct);
        _logger.LogInformation("[DispatchWorker] Month-end consolidation done — {Count} customer-shop pairs processed.", consolidations);
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private static bool IsDeliveryDueToday(string daysOfWeek, DateOnly date)
    {
        if (string.IsNullOrEmpty(daysOfWeek)) return true;

        var spec = daysOfWeek.Trim().ToUpperInvariant();
        if (spec == "EVERYDAY" || spec == "DAILY" || spec == "EVERY DAY") return true;

        if (spec == "WEEKDAYS")
            return date.DayOfWeek is not (DayOfWeek.Saturday or DayOfWeek.Sunday);

        if (spec == "WEEKENDS")
            return date.DayOfWeek is DayOfWeek.Saturday or DayOfWeek.Sunday;

        // Comma-separated day list: "MON,WED,FRI" or "Monday,Wednesday,Friday"
        var days = spec.Split(',').Select(d => d.Trim().ToUpperInvariant());
        var todayAbbrev = date.DayOfWeek.ToString().ToUpper()[..3]; // "MON", "TUE", etc.
        var todayFull = date.DayOfWeek.ToString().ToUpper();

        return days.Any(d => d.StartsWith(todayAbbrev) || d == todayFull);
    }
}
