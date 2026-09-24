using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.DTOs;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

[ApiController]
[Route("api/v1")]
public class SocialAndCommunityController : ControllerBase
{
    private readonly CoreDbContext _dbContext;
    private readonly IAuditService _auditService;

    public SocialAndCommunityController(CoreDbContext dbContext, IAuditService auditService)
    {
        _dbContext = dbContext;
        _auditService = auditService;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    // --- Social & Coffee Meetups ---

    [Authorize]
    [HttpPost("social/meetups")]
    public async Task<IActionResult> CreateMeetup([FromBody] CreateSocialMeetupRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var meetup = new SocialMeetup
        {
            CreatorId = userId.Value,
            Category = request.Category,
            Title = request.Title,
            Description = request.Description,
            ProposedTime = request.ProposedTime.ToUniversalTime(),
            LocationName = request.LocationName,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Status = "Open",
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.SocialMeetups.Add(meetup);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "SocialMeetupCreated",
            "SocialMeetup",
            meetup.Id.ToString(),
            details: $"{{\"category\":\"{meetup.Category}\", \"title\":\"{meetup.Title}\"}}"
        );

        return Ok(meetup);
    }

    [HttpGet("social/meetups")]
    public async Task<IActionResult> GetMeetups([FromQuery] string? category)
    {
        var query = _dbContext.SocialMeetups
            .Include(m => m.Creator)
            .Where(m => m.Status == "Open" && m.ProposedTime > DateTime.UtcNow);

        if (!string.IsNullOrEmpty(category))
        {
            query = query.Where(m => EF.Functions.ILike(m.Category, $"%{category}%"));
        }

        var list = await query.OrderBy(m => m.ProposedTime).Take(50).ToListAsync();

        return Ok(list.Select(m => new
        {
            m.Id,
            m.Category,
            m.Title,
            m.Description,
            m.ProposedTime,
            m.LocationName,
            m.Latitude,
            m.Longitude,
            m.Status,
            CreatorName = m.Creator?.FullName,
            CreatorAvatar = m.Creator?.AvatarUrl,
            m.CreatedAt
        }));
    }

    // --- Community Classifieds & Hyper-Local Requests (e.g. Teacher for Kids, Home Services) ---

    [Authorize]
    [HttpPost("community/classifieds")]
    public async Task<IActionResult> CreateClassified([FromBody] CreateClassifiedRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var classified = new CommunityClassified
        {
            PosterId = userId.Value,
            Category = request.Category,
            Title = request.Title,
            Description = request.Description,
            Budget = request.Budget,
            LocationName = request.LocationName,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Status = "Active",
            CreatedAt = DateTime.UtcNow
        };

        _dbContext.CommunityClassifieds.Add(classified);
        await _dbContext.SaveChangesAsync();

        await _auditService.LogActionAsync(
            userId.Value,
            "CommunityClassifiedPosted",
            "CommunityClassified",
            classified.Id.ToString(),
            details: $"{{\"category\":\"{classified.Category}\", \"title\":\"{classified.Title}\", \"budget\":{classified.Budget}}}"
        );

        return Ok(classified);
    }

    [HttpGet("community/classifieds")]
    public async Task<IActionResult> GetClassifieds([FromQuery] string? category, [FromQuery] string? search)
    {
        var query = _dbContext.CommunityClassifieds
            .Include(c => c.Poster)
            .Where(c => c.Status == "Active");

        if (!string.IsNullOrEmpty(category))
        {
            query = query.Where(c => EF.Functions.ILike(c.Category, $"%{category}%"));
        }

        if (!string.IsNullOrEmpty(search))
        {
            query = query.Where(c => EF.Functions.ILike(c.Title, $"%{search}%") || EF.Functions.ILike(c.Description, $"%{search}%"));
        }

        var list = await query.OrderByDescending(c => c.CreatedAt).Take(50).ToListAsync();

        return Ok(list.Select(c => new
        {
            c.Id,
            c.Category,
            c.Title,
            c.Description,
            c.Budget,
            c.LocationName,
            c.Latitude,
            c.Longitude,
            c.Status,
            PosterName = c.Poster?.FullName,
            PosterPhone = c.Poster?.Phone,
            c.CreatedAt
        }));
    }
}
