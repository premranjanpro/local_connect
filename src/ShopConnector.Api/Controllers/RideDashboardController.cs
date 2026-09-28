using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Api.Hubs;
using ShopConnector.Api.Services;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

/// <summary>
/// Ride Dashboard — manages multi-task single rides.
///
/// Driver interaction model (MINIMAL REQUIRED):
///   1. POST /api/v1/rides                         — create ride with task list
///   2. POST /api/v1/rides/{id}/start              — START RIDE (just tap it, done)
///   3. POST /api/v1/rides/{id}/end                — END RIDE (just tap it, done)
///
/// Driver OPTIONAL actions (anytime during ride):
///   POST /api/v1/rides/{id}/tasks/{taskId}/manual-alert — "Get ready, coming to you!"
///   POST /api/v1/rides/{id}/tasks/{taskId}/picked-up   — mark individual pickup
///   POST /api/v1/rides/{id}/tasks/{taskId}/dropped     — mark individual drop
///   POST /api/v1/rides/{id}/location-ping              — GPS position (auto-geofence)
///
/// Automatic (no driver action needed):
///   - Geofence detection on location-ping → notify approaching recipients
///   - Task completion marked when EndRide if not already marked
///
/// GET  /api/v1/rides/{id}                         — full ride with all tasks + stops
/// GET  /api/v1/rides/active                        — driver's current active ride
/// </summary>
[ApiController]
[Route("api/v1/rides")]
[Authorize]
public class RideDashboardController : ControllerBase
{
    private readonly CoreDbContext _db;
    private readonly INotificationEnqueueService _notifQueue;
    private readonly IWebhookService _webhookService;
    private readonly IHubContext<TaskHub> _hub;
    private readonly IAuditService _audit;

    private const int MaxManualAlertsPerTask = 3;
    private const int ManualAlertCooldownSeconds = 120; // 2 min between manual alerts per task

    public RideDashboardController(
        CoreDbContext db, INotificationEnqueueService notifQueue,
        IWebhookService webhookService, IHubContext<TaskHub> hub, IAuditService audit)
    {
        _db = db; _notifQueue = notifQueue;
        _webhookService = webhookService; _hub = hub; _audit = audit;
    }

    private Guid? GetUserId()
    {
        var s = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(s, out var id) ? id : null;
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  CREATE ride — bundle multiple tasks into one trip
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Creates a ride session linking multiple tasks.
    /// Can be created by shop owner (assigning driver to batch) or driver themselves.
    /// Task order is the planned sequence — driver can do them in any order.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> CreateRide([FromBody] CreateRideRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        if (req.TaskIds == null || req.TaskIds.Count == 0)
            return BadRequest(new { message = "At least 1 task required." });

        // Validate all tasks belong to this driver or are unassigned
        var tasks = await _db.Tasks
            .Include(t => t.Stops)
            .Include(t => t.Customer)
            .Where(t => req.TaskIds.Contains(t.Id) && !t.IsDeleted)
            .ToListAsync();

        if (tasks.Count != req.TaskIds.Count)
            return BadRequest(new { message = "Some tasks not found or deleted." });

        var ride = new RideSession
        {
            DriverId = req.DriverId ?? userId.Value,
            RideName = req.RideName,
            Status = "PENDING",
            CreatedAt = DateTime.UtcNow
        };
        _db.RideSessions.Add(ride);
        await _db.SaveChangesAsync();

        // Link tasks in planned sequence
        var seq = 1;
        foreach (var tid in req.TaskIds)
        {
            _db.RideTasks.Add(new RideTask
            {
                RideSessionId = ride.Id,
                TaskId = tid,
                PlannedSequence = seq++,
                Status = "PENDING"
            });

            // Assign driver to each task
            var task = tasks.FirstOrDefault(t => t.Id == tid);
            if (task != null && task.AssignedDriverId == null)
            {
                task.AssignedDriverId = ride.DriverId;
                task.Status = "Accepted";
            }
        }

        await _db.SaveChangesAsync();

        // Notify all recipients: "Order confirmed, driver assigned"
        foreach (var task in tasks)
        {
            var recipientId = task.CustomerId;
            await _notifQueue.EnqueueAsync(
                title: "🚗 Driver Assigned!",
                body: $"Your driver has been assigned for {task.TaskType}. Ride starts soon.",
                recipientUserId: recipientId,
                taskId: task.Id,
                channel: "BOTH",
                extraData: new() { { "rideId", ride.Id.ToString() }, { "type", "driver_assigned" } }
            );

            // Notify each task stop recipient too
            foreach (var stop in task.Stops.Where(s => s.RecipientUserId != null || s.RecipientPhone != null))
            {
                var stopType = stop.StopType == "PICKUP" ? "pickup" : "drop";
                await _notifQueue.EnqueueAsync(
                    title: "📦 Your order is scheduled",
                    body: $"Driver assigned for your {stopType} at {stop.Address}. You'll get notified when driver approaches.",
                    recipientUserId: stop.RecipientUserId,
                    recipientPhone: stop.RecipientPhone,
                    taskId: task.Id, taskStopId: stop.Id,
                    channel: "BOTH"
                );
            }
        }

        return Ok(new
        {
            rideId = ride.Id,
            rideName = ride.RideName,
            status = ride.Status,
            totalTasks = tasks.Count,
            message = "Ride created. Press 'Start Ride' when ready to begin.",
            tasks = tasks.Select((t, i) => new
            {
                sequence = i + 1,
                taskId = t.Id,
                taskType = t.TaskType,
                pickupAddress = t.PickupAddress,
                dropoffAddress = t.DropoffAddress,
                customerName = t.Customer?.FullName,
                stops = t.Stops.Count
            })
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  START RIDE — single tap, marks whole ride active
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Driver taps START RIDE — one button, entire ride begins.
    /// Notifies ALL task recipients: "Driver started — on the way!"
    /// Driver does NOT need to mark individual pickups (but can).
    /// </summary>
    [HttpPost("{id}/start")]
    public async Task<IActionResult> StartRide(Guid id, [FromBody] GpsEventRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ride = await _db.RideSessions
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Customer)
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Stops)
            .FirstOrDefaultAsync(r => r.Id == id && r.DriverId == userId.Value);

        if (ride == null) return NotFound();
        if (ride.Status == "ACTIVE")
            return BadRequest(new { message = "Ride already started." });
        if (ride.Status == "COMPLETED")
            return BadRequest(new { message = "Ride already completed." });

        ride.Status = "ACTIVE";
        ride.StartedAt = DateTime.UtcNow;
        ride.StartLat = req.DriverLat;
        ride.StartLng = req.DriverLng;

        // Mark all tasks EN_ROUTE
        foreach (var rt in ride.RideTasks)
        {
            if (rt.Task == null) continue;
            rt.Task.Status = "EN_ROUTE_PICKUP";
        }

        await _db.SaveChangesAsync();

        await _audit.LogActionAsync(userId.Value, "RideStarted", "RideSession", ride.Id.ToString(),
            details: $"{{\"lat\":{req.DriverLat},\"lng\":{req.DriverLng},\"tasks\":{ride.RideTasks.Count}}}");

        // Notify ALL recipients: driver started
        var notifTasks = new List<Task>();
        foreach (var rt in ride.RideTasks)
        {
            if (rt.Task?.Customer == null) continue;

            var body = ride.RideTasks.Count > 1
                ? $"Your driver has started the ride. {ride.RideTasks.Count} deliveries in this trip. You'll be notified when driver approaches."
                : "Your driver has started and is on the way!";

            notifTasks.Add(_notifQueue.EnqueueAsync(
                title: "🚗 Driver Started!",
                body: body,
                recipientUserId: rt.Task.CustomerId,
                taskId: rt.TaskId,
                channel: "BOTH",
                extraData: new() { { "rideId", id.ToString() }, { "status", "EN_ROUTE_PICKUP" } }
            ));

            // Also notify stop-level recipients
            foreach (var stop in rt.Task.Stops.Where(s => s.RecipientPhone != null || s.RecipientUserId != null))
            {
                notifTasks.Add(_notifQueue.EnqueueAsync(
                    title: "🚗 Driver on the way!",
                    body: $"Driver started. Your {stop.StopType.ToLower()} at {stop.Address} coming up.",
                    recipientUserId: stop.RecipientUserId,
                    recipientPhone: stop.RecipientPhone,
                    taskId: rt.TaskId, taskStopId: stop.Id, channel: "BOTH"
                ));
            }
        }
        await Task.WhenAll(notifTasks);

        await _hub.Clients.All.SendAsync("OnRideStarted", new
        {
            rideId = id, driverLat = req.DriverLat, driverLng = req.DriverLng,
            taskCount = ride.RideTasks.Count
        });

        return Ok(new
        {
            message = $"✅ Ride started! {ride.RideTasks.Count} task(s) in this ride.",
            rideId = id,
            status = "ACTIVE",
            startedAt = ride.StartedAt,
            hint = "You'll get auto-alerts as you approach each stop. Tap 'End Ride' when all done."
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  END RIDE — single tap, closes entire ride
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Driver taps END RIDE — all tasks auto-completed if not already.
    /// Calculates total km + duration. Notifies all recipients.
    /// </summary>
    [HttpPost("{id}/end")]
    public async Task<IActionResult> EndRide(Guid id, [FromBody] EndRideRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ride = await _db.RideSessions
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Customer)
            .FirstOrDefaultAsync(r => r.Id == id && r.DriverId == userId.Value);

        if (ride == null) return NotFound();
        if (ride.Status != "ACTIVE")
            return BadRequest(new { message = $"Ride is {ride.Status}, not ACTIVE." });

        ride.Status = "COMPLETED";
        ride.EndedAt = DateTime.UtcNow;
        ride.EndLat = req.DriverLat;
        ride.EndLng = req.DriverLng;
        ride.TotalKm = req.TotalKm;
        ride.TotalMinutes = ride.StartedAt.HasValue
            ? (int)(DateTime.UtcNow - ride.StartedAt.Value).TotalMinutes : 0;

        // Auto-complete any unfinished ride tasks
        var notifTasks = new List<Task>();
        foreach (var rt in ride.RideTasks)
        {
            if (rt.Task == null) continue;
            if (rt.Status != "DROPPED" && rt.Status != "SKIPPED")
            {
                rt.Status = "DROPPED";
                rt.DroppedAt = DateTime.UtcNow;
            }
            if (rt.Task.Status != "Completed" && rt.Task.Status != "Cancelled")
            {
                rt.Task.Status = "Completed";
                rt.Task.CompletedAt = DateTime.UtcNow;
            }

            notifTasks.Add(_notifQueue.EnqueueAsync(
                title: "✅ Delivery Completed!",
                body: $"Your delivery/pickup is complete. Ride total: {req.TotalKm:F1}km in {ride.TotalMinutes} min. Thank you!",
                recipientUserId: rt.Task.CustomerId,
                taskId: rt.TaskId,
                channel: "BOTH",
                extraData: new() { { "rideId", id.ToString() }, { "totalKm", req.TotalKm.ToString("F1") } }
            ));

            await _webhookService.FireAsync("task.completed", new
            {
                taskId = rt.TaskId, rideId = id,
                totalKm = req.TotalKm, durationMinutes = ride.TotalMinutes
            }, businessId: rt.Task.BusinessId);
        }
        await Task.WhenAll(notifTasks);
        await _db.SaveChangesAsync();

        await _audit.LogActionAsync(userId.Value, "RideEnded", "RideSession", ride.Id.ToString(),
            details: $"{{\"totalKm\":{req.TotalKm},\"minutes\":{ride.TotalMinutes}}}");

        await _hub.Clients.All.SendAsync("OnRideEnded", new
        {
            rideId = id, totalKm = req.TotalKm, totalMinutes = ride.TotalMinutes
        });

        return Ok(new
        {
            message = "✅ Ride completed!",
            rideId = id,
            totalKm = req.TotalKm,
            totalMinutes = ride.TotalMinutes,
            tasksCompleted = ride.RideTasks.Count,
            endedAt = ride.EndedAt
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  MANUAL ALERT — driver sends "Get ready!" to specific recipient
    // ═══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Driver manually sends a "Get Ready" alert to a specific task's recipient.
    /// Use case: "I just finished pickup A, sending alert to B that I'm coming next."
    ///
    /// Rules:
    ///   - Max 3 manual alerts per task per ride
    ///   - 2 min cooldown between alerts per task
    ///   - Custom message supported (or uses default)
    /// </summary>
    [HttpPost("{id}/tasks/{taskId}/manual-alert")]
    public async Task<IActionResult> SendManualAlert(
        Guid id, Guid taskId, [FromBody] ManualAlertRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ride = await _db.RideSessions
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Stops)
            .FirstOrDefaultAsync(r => r.Id == id && r.DriverId == userId.Value);

        if (ride == null) return NotFound();
        if (ride.Status != "ACTIVE")
            return BadRequest(new { message = "Ride must be active to send alerts." });

        var rideTask = ride.RideTasks.FirstOrDefault(rt => rt.TaskId == taskId);
        if (rideTask?.Task == null)
            return NotFound(new { message = "Task not part of this ride." });

        // Rate limit check
        if (rideTask.ManualAlertCount >= MaxManualAlertsPerTask)
            return BadRequest(new { message = $"Maximum {MaxManualAlertsPerTask} manual alerts per task reached." });

        if (rideTask.LastManualAlertAt.HasValue &&
            (DateTime.UtcNow - rideTask.LastManualAlertAt.Value).TotalSeconds < ManualAlertCooldownSeconds)
        {
            var waitSec = ManualAlertCooldownSeconds - (int)(DateTime.UtcNow - rideTask.LastManualAlertAt.Value).TotalSeconds;
            return BadRequest(new { message = $"Wait {waitSec}s before sending another alert to this recipient." });
        }

        rideTask.ManualAlertCount++;
        rideTask.LastManualAlertAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        var task = rideTask.Task;
        var defaultMsg = req.Message ?? $"🚗 Your driver is coming to you next! Get ready for your {task.TaskType.ToLower()}.";
        var title = req.Title ?? "Get Ready — Driver Coming!";

        // Send to main customer
        await _notifQueue.EnqueueAsync(
            title: title,
            body: defaultMsg,
            recipientUserId: task.CustomerId,
            taskId: taskId,
            channel: "BOTH",
            extraData: new() { { "rideId", id.ToString() }, { "type", "manual_alert" }, { "alertNum", rideTask.ManualAlertCount.ToString() } }
        );

        // Also alert per-stop recipients if specified
        var alertedStops = new List<string>();
        foreach (var stop in task.Stops.Where(s =>
            (req.StopId == null || s.Id == req.StopId) &&
            (s.RecipientPhone != null || s.RecipientUserId != null) &&
            s.Status != "COMPLETED"))
        {
            await _notifQueue.EnqueueAsync(
                title: title,
                body: $"🚗 Driver is on the way to your {stop.StopType.ToLower()} at {stop.Address}! Get ready.",
                recipientUserId: stop.RecipientUserId,
                recipientPhone: stop.RecipientPhone,
                taskId: taskId, taskStopId: stop.Id,
                channel: "BOTH",
                extraData: new() { { "type", "manual_alert" }, { "stopSeq", stop.StopSequence.ToString() } }
            );
            alertedStops.Add($"Stop #{stop.StopSequence} — {stop.RecipientLabel ?? stop.Address}");
        }

        await _audit.LogActionAsync(userId.Value, "ManualAlertSent", "RideTask", rideTask.Id.ToString(),
            details: $"{{\"taskId\":\"{taskId}\",\"alertNum\":{rideTask.ManualAlertCount}}}");

        return Ok(new
        {
            message = $"Alert sent! ({rideTask.ManualAlertCount}/{MaxManualAlertsPerTask} manual alerts used)",
            title,
            body = defaultMsg,
            alertedRecipients = alertedStops.Count + 1,
            alertedStops,
            remaining = MaxManualAlertsPerTask - rideTask.ManualAlertCount,
            cooldownSeconds = ManualAlertCooldownSeconds
        });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  OPTIONAL: Mark individual pickup / drop (not required by driver)
    // ═══════════════════════════════════════════════════════════════════════

    [HttpPost("{id}/tasks/{taskId}/picked-up")]
    public async Task<IActionResult> MarkPickedUp(Guid id, Guid taskId, [FromBody] GpsEventRequest req)
    {
        var (userId, rideTask, err) = await GetRideTask(id, taskId);
        if (err != null) return err;

        rideTask!.Status = "PICKED_UP";
        rideTask.PickedUpAt = DateTime.UtcNow;
        if (rideTask.Task != null) rideTask.Task.Status = "PICKED_UP";
        await _db.SaveChangesAsync();

        await _notifQueue.EnqueueAsync(
            title: "📦 Pickup Done!",
            body: $"Driver has picked up your package at {rideTask.Task?.PickupAddress}.",
            recipientUserId: rideTask.Task?.CustomerId,
            taskId: taskId, channel: "BOTH",
            extraData: new() { { "rideId", id.ToString() }, { "status", "PICKED_UP" } }
        );

        return Ok(new { message = "Pickup marked!", taskId, status = "PICKED_UP" });
    }

    [HttpPost("{id}/tasks/{taskId}/dropped")]
    public async Task<IActionResult> MarkDropped(Guid id, Guid taskId, [FromBody] GpsEventRequest req)
    {
        var (userId, rideTask, err) = await GetRideTask(id, taskId);
        if (err != null) return err;

        rideTask!.Status = "DROPPED";
        rideTask.DroppedAt = DateTime.UtcNow;
        if (rideTask.Task != null) { rideTask.Task.Status = "Completed"; rideTask.Task.CompletedAt = DateTime.UtcNow; }
        await _db.SaveChangesAsync();

        await _notifQueue.EnqueueAsync(
            title: "✅ Delivered!",
            body: $"Your package was delivered to {rideTask.Task?.DropoffAddress}.",
            recipientUserId: rideTask.Task?.CustomerId,
            taskId: taskId, channel: "BOTH"
        );

        return Ok(new { message = "Dropped marked!", taskId, status = "DROPPED" });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  GPS LOCATION PING — auto geofence check for all pending stops in ride
    // ═══════════════════════════════════════════════════════════════════════

    [HttpPost("{id}/location-ping")]
    public async Task<IActionResult> LocationPing(Guid id, [FromBody] LocationPingRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ride = await _db.RideSessions
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Stops)
            .FirstOrDefaultAsync(r => r.Id == id && r.DriverId == userId.Value && r.Status == "ACTIVE");

        if (ride == null) return NotFound();

        var triggered = new List<object>();

        foreach (var rt in ride.RideTasks.Where(rt => rt.Status == "PENDING" || rt.Status == "PICKED_UP"))
        {
            if (rt.Task == null) continue;
            foreach (var stop in rt.Task.Stops.Where(s => s.Status == "PENDING" && !s.ProximityNotified))
            {
                var dist = GeofenceHelper.DistanceMeters(req.Lat, req.Lng, stop.Latitude, stop.Longitude);
                if (dist <= stop.GeofenceRadiusMeters)
                {
                    stop.ProximityNotified = true;
                    stop.ProximityNotifiedAt = DateTime.UtcNow;
                    stop.Status = "DRIVER_APPROACHING";

                    var etaMin = Math.Max(1, (int)(dist / 250.0));
                    var stopType = stop.StopType == "PICKUP" ? "pickup" : "delivery";

                    await _notifQueue.EnqueueAsync(
                        title: $"🚗 Driver arriving in ~{etaMin} min!",
                        body: $"Driver is {(int)dist}m away from your {stopType} at {stop.Address}. Be ready!",
                        recipientUserId: stop.RecipientUserId,
                        recipientPhone: stop.RecipientPhone,
                        taskId: rt.TaskId, taskStopId: stop.Id,
                        channel: "BOTH",
                        extraData: new() { { "rideId", id.ToString() }, { "etaMin", etaMin.ToString() }, { "type", "approaching" } }
                    );

                    triggered.Add(new { stop.Id, stop.StopSequence, etaMin, distanceMeters = (int)dist, address = stop.Address });
                }
            }
        }

        if (triggered.Count > 0) await _db.SaveChangesAsync();

        // Broadcast to SignalR for map animation
        await _hub.Clients.Group($"ride_{id}").SendAsync("OnDriverLocationUpdate", new
        {
            rideId = id, lat = req.Lat, lng = req.Lng,
            bearing = req.Bearing, speed = req.Speed
        });

        return Ok(new { proximityAlerts = triggered.Count, triggered });
    }

    // ═══════════════════════════════════════════════════════════════════════
    //  GET RIDE — full dashboard data
    // ═══════════════════════════════════════════════════════════════════════

    [HttpGet("{id}")]
    public async Task<IActionResult> GetRide(Guid id)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ride = await _db.RideSessions
            .Include(r => r.Driver)
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Customer)
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Stops)
            .Include(r => r.RideTasks)
                .ThenInclude(rt => rt.Task)
                    .ThenInclude(t => t!.Business)
            .FirstOrDefaultAsync(r => r.Id == id);

        if (ride == null) return NotFound();

        var completed = ride.RideTasks.Count(rt => rt.Status is "DROPPED" or "SKIPPED");
        var total = ride.RideTasks.Count;

        return Ok(new
        {
            ride.Id,
            ride.RideName,
            ride.Status,
            ride.StartedAt,
            ride.EndedAt,
            ride.TotalKm,
            ride.TotalMinutes,
            driverName = ride.Driver?.FullName,
            progress = $"{completed}/{total}",
            progressPercent = total > 0 ? (completed * 100 / total) : 0,
            tasks = ride.RideTasks.OrderBy(rt => rt.PlannedSequence).Select(rt => new
            {
                rt.Id,
                rt.PlannedSequence,
                rt.TaskId,
                rt.Status,
                rt.PickedUpAt,
                rt.DroppedAt,
                rt.ManualAlertCount,
                manualAlertsRemaining = MaxManualAlertsPerTask - rt.ManualAlertCount,
                task = rt.Task == null ? null : new
                {
                    rt.Task.TaskType,
                    rt.Task.Status,
                    rt.Task.PickupAddress,
                    rt.Task.DropoffAddress,
                    rt.Task.FareAmount,
                    customerName = rt.Task.Customer?.FullName,
                    customerPhone = rt.Task.Customer?.Phone,
                    businessName = rt.Task.Business?.Name,
                    stops = rt.Task.Stops.OrderBy(s => s.StopSequence).Select(s => new
                    {
                        s.Id, s.StopSequence, s.StopType, s.Address,
                        s.RecipientLabel, s.RecipientPhone,
                        s.Status, s.IsOtpRequired,
                        s.GeofenceRadiusMeters, s.ProximityNotified,
                        geofenceIcon = s.GeofenceStatus switch
                        {
                            "OK" => "✅", "ALERT" => "🚨", "WARNING" => "⚠️", _ => "—"
                        }
                    })
                }
            })
        });
    }

    [HttpGet("active")]
    public async Task<IActionResult> GetActiveRide()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var ride = await _db.RideSessions
            .Include(r => r.RideTasks).ThenInclude(rt => rt.Task)
            .FirstOrDefaultAsync(r => r.DriverId == userId.Value && r.Status == "ACTIVE");

        if (ride == null) return NotFound(new { message = "No active ride." });
        return await GetRide(ride.Id);
    }

    // ── Helper ────────────────────────────────────────────────────────────

    private async Task<(Guid? userId, RideTask? rideTask, IActionResult? err)> GetRideTask(Guid rideId, Guid taskId)
    {
        var userId = GetUserId();
        if (userId == null) return (null, null, Unauthorized());

        var ride = await _db.RideSessions
            .Include(r => r.RideTasks).ThenInclude(rt => rt.Task).ThenInclude(t => t!.Stops)
            .FirstOrDefaultAsync(r => r.Id == rideId && r.DriverId == userId.Value);

        if (ride == null) return (userId, null, NotFound());
        if (ride.Status != "ACTIVE") return (userId, null, BadRequest(new { message = "Ride not active." }));

        var rt = ride.RideTasks.FirstOrDefault(t => t.TaskId == taskId);
        if (rt == null) return (userId, null, NotFound(new { message = "Task not in ride." }));

        return (userId, rt, null);
    }
}

// ── DTOs ─────────────────────────────────────────────────────────────────────

public record CreateRideRequest(
    List<Guid> TaskIds,
    string? RideName = null,
    Guid? DriverId = null
);

public record EndRideRequest(
    double DriverLat,
    double DriverLng,
    decimal TotalKm = 0
);

public record ManualAlertRequest(
    string? Message = null,
    string? Title = null,
    Guid? StopId = null   // null = alert all pending stops, specific = one stop
);
