using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1/tasks/{taskId:guid}/ratings")]
[Authorize]
public class RatingsController : ControllerBase
{
    private readonly CoreDbContext _db;

    public RatingsController(CoreDbContext db)
    {
        _db = db;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    /// <summary>
    /// GET /api/v1/tasks/{taskId}/ratings/status
    /// Checks what ratings have been submitted for this task.
    /// </summary>
    [HttpGet("status")]
    public async Task<IActionResult> GetRatingStatus(Guid taskId)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Customer)
            .Include(t => t.AssignedDriver)
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == taskId);

        if (task == null) return NotFound(new { message = "Task not found." });

        var existingRatings = await _db.TaskRatings
            .Where(r => r.TaskId == taskId)
            .ToListAsync();

        var myRatings = existingRatings.Where(r => r.FromUserId == userId.Value).ToList();

        bool isCustomer = task.CustomerId == userId.Value;
        bool isDriver = task.AssignedDriverId == userId.Value;
        bool isMerchant = task.Business?.MerchantId == userId.Value;

        return Ok(new
        {
            taskId = task.Id,
            taskStatus = task.Status,
            isCompleted = task.Status.Equals("Completed", StringComparison.OrdinalIgnoreCase),
            userRole = isCustomer ? "Customer" : (isDriver ? "Driver" : (isMerchant ? "Merchant" : "Other")),
            driver = task.AssignedDriver == null ? null : new
            {
                id = task.AssignedDriver.Id,
                name = task.AssignedDriver.FullName,
                avatarUrl = task.AssignedDriver.AvatarUrl
            },
            shop = task.Business == null ? null : new
            {
                id = task.Business.Id,
                name = task.Business.Name
            },
            customer = task.Customer == null ? null : new
            {
                id = task.Customer.Id,
                name = task.Customer.FullName,
                avatarUrl = task.Customer.AvatarUrl
            },
            hasRatedDriver = myRatings.Any(r => r.TargetType.Equals("Driver", StringComparison.OrdinalIgnoreCase)),
            hasRatedShop = myRatings.Any(r => r.TargetType.Equals("Shop", StringComparison.OrdinalIgnoreCase)),
            hasRatedCustomer = myRatings.Any(r => r.TargetType.Equals("Customer", StringComparison.OrdinalIgnoreCase)),
            submittedRatings = myRatings.Select(r => new
            {
                targetType = r.TargetType,
                stars = r.RatingStars,
                tags = r.FeedbackTags,
                review = r.ReviewText,
                createdAt = r.CreatedAt
            })
        });
    }

    /// <summary>
    /// POST /api/v1/tasks/{taskId}/ratings
    /// Submits rating from Driver to Customer, or Customer to Driver & Shop.
    /// </summary>
    [HttpPost]
    public async Task<IActionResult> SubmitRating(Guid taskId, [FromBody] SubmitTaskRatingRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var task = await _db.Tasks
            .Include(t => t.Customer)
            .Include(t => t.AssignedDriver)
            .Include(t => t.Business)
            .FirstOrDefaultAsync(t => t.Id == taskId);

        if (task == null) return NotFound(new { message = "Task not found." });

        bool isCustomer = task.CustomerId == userId.Value;
        bool isDriver = task.AssignedDriverId == userId.Value;
        bool isMerchant = task.Business?.MerchantId == userId.Value;

        if (!isCustomer && !isDriver && !isMerchant)
            return Forbid();

        string fromRole = isCustomer ? "Customer" : (isDriver ? "Driver" : "Merchant");

        var createdRatings = new List<TaskRating>();

        foreach (var item in req.Ratings)
        {
            if (item.RatingStars < 1 || item.RatingStars > 5)
                return BadRequest(new { message = "Rating must be between 1 and 5 stars." });

            string target = item.TargetType.Trim();

            // Check if caller already rated this target on this task
            var alreadyExists = await _db.TaskRatings.AnyAsync(r =>
                r.TaskId == taskId &&
                r.FromUserId == userId.Value &&
                r.TargetType.ToLower() == target.ToLower());

            if (alreadyExists)
                continue; // Skip already rated target

            Guid? toUserId = null;
            Guid? businessId = null;

            if (target.Equals("Driver", StringComparison.OrdinalIgnoreCase))
            {
                if (!isCustomer && !isMerchant)
                    return BadRequest(new { message = "Only customer or merchant can rate the driver." });

                if (task.AssignedDriverId == null)
                    return BadRequest(new { message = "No driver assigned to this task." });

                toUserId = task.AssignedDriverId.Value;

                // Update DriverProfile rating
                var profile = await _db.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == toUserId.Value);
                if (profile != null)
                {
                    var oldCount = profile.RatingCount;
                    var oldRating = profile.Rating;
                    var newRating = Math.Round(((oldRating * oldCount) + item.RatingStars) / (oldCount + 1), 2);
                    profile.Rating = Math.Clamp(newRating, 1.0m, 5.0m);
                    profile.RatingCount = oldCount + 1;
                    profile.UpdatedAt = DateTime.UtcNow;
                }
            }
            else if (target.Equals("Customer", StringComparison.OrdinalIgnoreCase))
            {
                if (!isDriver && !isMerchant)
                    return BadRequest(new { message = "Only driver or merchant can rate the customer." });

                toUserId = task.CustomerId;

                // Update User CustomerRating
                var customerUser = await _db.Users.FirstOrDefaultAsync(u => u.Id == toUserId.Value);
                if (customerUser != null)
                {
                    var oldCount = customerUser.RatingCount;
                    var oldRating = customerUser.CustomerRating;
                    var newRating = Math.Round(((oldRating * oldCount) + item.RatingStars) / (oldCount + 1), 2);
                    customerUser.CustomerRating = Math.Clamp(newRating, 1.0m, 5.0m);
                    customerUser.RatingCount = oldCount + 1;
                    customerUser.UpdatedAt = DateTime.UtcNow;
                }
            }
            else if (target.Equals("Shop", StringComparison.OrdinalIgnoreCase) || target.Equals("Merchant", StringComparison.OrdinalIgnoreCase))
            {
                if (!isCustomer)
                    return BadRequest(new { message = "Only customer can rate the shop owner." });

                if (task.BusinessId == null)
                    return BadRequest(new { message = "No shop associated with this task." });

                businessId = task.BusinessId.Value;
                toUserId = task.Business?.MerchantId;

                // Update Business rating
                var biz = await _db.Businesses.FirstOrDefaultAsync(b => b.Id == businessId.Value);
                if (biz != null)
                {
                    var oldCount = biz.RatingCount;
                    var oldRating = biz.Rating;
                    var newRating = Math.Round(((oldRating * oldCount) + item.RatingStars) / (oldCount + 1), 2);
                    biz.Rating = Math.Clamp(newRating, 1.0m, 5.0m);
                    biz.RatingCount = oldCount + 1;
                    biz.UpdatedAt = DateTime.UtcNow;
                }
            }
            else
            {
                return BadRequest(new { message = $"Unknown target type: {target}" });
            }

            var tagsStr = item.FeedbackTags != null && item.FeedbackTags.Count > 0
                ? string.Join(", ", item.FeedbackTags)
                : null;

            var ratingRecord = new TaskRating
            {
                TaskId = taskId,
                FromUserId = userId.Value,
                FromRole = fromRole,
                ToUserId = toUserId,
                BusinessId = businessId,
                TargetType = target,
                RatingStars = item.RatingStars,
                FeedbackTags = tagsStr,
                ReviewText = item.ReviewText,
                CreatedAt = DateTime.UtcNow
            };

            _db.TaskRatings.Add(ratingRecord);
            createdRatings.Add(ratingRecord);
        }

        await _db.SaveChangesAsync();

        return Ok(new
        {
            success = true,
            message = "Thank you! Your rating and feedback have been recorded.",
            submittedCount = createdRatings.Count
        });
    }
}

public record SubmitRatingItem(
    string TargetType,               // "Driver" | "Customer" | "Shop"
    int RatingStars,                 // 1 to 5
    List<string>? FeedbackTags = null,
    string? ReviewText = null
);

public record SubmitTaskRatingRequest(
    List<SubmitRatingItem> Ratings
);
