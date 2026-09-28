using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Api.Hubs;
using ShopConnector.Core.Entities;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Controllers;

/// <summary>
/// REST companion to ChatHub — lets HTTP clients query message history,
/// unread counts, and conversation threads without an active WebSocket.
/// </summary>
[ApiController]
[Route("api/v1/chat")]
[Authorize]
public class ChatController : ControllerBase
{
    private readonly CoreDbContext _db;
    private readonly IHubContext<ChatHub> _chatHub;

    public ChatController(CoreDbContext db, IHubContext<ChatHub> chatHub)
    {
        _db = db;
        _chatHub = chatHub;
    }

    private Guid? GetUserId()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    // ── Task Thread History ─────────────────────────────────────────────────

    /// <summary>GET /api/v1/chat/task/{taskId}?page=0&size=30</summary>
    [HttpGet("task/{taskId}")]
    public async Task<IActionResult> GetTaskChatHistory(Guid taskId, [FromQuery] int page = 0, [FromQuery] int size = 30)
    {
        var roomKey = $"chat_task_{taskId}";
        var messages = await _db.ChatMessages
            .Where(m => m.RoomKey == roomKey)
            .OrderByDescending(m => m.CreatedAt)
            .Skip(page * size)
            .Take(size)
            .OrderBy(m => m.CreatedAt)
            .Select(m => new
            {
                m.Id,
                m.SenderId,
                SenderName = m.Sender != null ? m.Sender.FullName : "Unknown",
                m.SenderRole,
                m.Body,
                m.MessageType,
                m.AttachmentUrl,
                m.IsRead,
                m.CreatedAt
            })
            .ToListAsync();

        return Ok(new { taskId, page, size, messages });
    }

    // ── Direct Message History ──────────────────────────────────────────────

    /// <summary>GET /api/v1/chat/dm/{otherUserId}?page=0&size=30</summary>
    [HttpGet("dm/{otherUserId}")]
    public async Task<IActionResult> GetDmHistory(Guid otherUserId, [FromQuery] int page = 0, [FromQuery] int size = 30)
    {
        var myId = GetUserId();
        if (myId == null) return Unauthorized();

        var sorted = new[] { myId.Value.ToString(), otherUserId.ToString() }.OrderBy(x => x).ToArray();
        var roomKey = $"chat_dm_{sorted[0]}_{sorted[1]}";

        var messages = await _db.ChatMessages
            .Where(m => m.RoomKey == roomKey)
            .OrderByDescending(m => m.CreatedAt)
            .Skip(page * size)
            .Take(size)
            .OrderBy(m => m.CreatedAt)
            .Select(m => new
            {
                m.Id,
                m.SenderId,
                SenderName = m.Sender != null ? m.Sender.FullName : "Unknown",
                m.SenderRole,
                m.Body,
                m.MessageType,
                m.AttachmentUrl,
                m.IsRead,
                m.CreatedAt
            })
            .ToListAsync();

        return Ok(new { otherUserId, page, size, messages });
    }

    // ── My Unread Counts ────────────────────────────────────────────────────

    /// <summary>GET /api/v1/chat/unread — returns total unread count per room for the current user</summary>
    [HttpGet("unread")]
    public async Task<IActionResult> GetUnreadCounts()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var unread = await _db.ChatMessages
            .Where(m => !m.IsRead && m.SenderId != userId.Value)
            .GroupBy(m => m.RoomKey)
            .Select(g => new { roomKey = g.Key, count = g.Count() })
            .ToListAsync();

        return Ok(new { totalUnread = unread.Sum(u => u.count), rooms = unread });
    }

    // ── My Conversations List ───────────────────────────────────────────────

    /// <summary>GET /api/v1/chat/conversations — latest message per room the user is involved in</summary>
    [HttpGet("conversations")]
    public async Task<IActionResult> GetConversations()
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        // Find all room keys where the current user has sent or received a message
        var myRooms = await _db.ChatMessages
            .Where(m => m.SenderId == userId.Value ||
                        m.RoomKey.Contains(userId.Value.ToString().ToLowerInvariant()))
            .Select(m => m.RoomKey)
            .Distinct()
            .ToListAsync();

        var conversations = new List<object>();
        foreach (var room in myRooms)
        {
            var latest = await _db.ChatMessages
                .Where(m => m.RoomKey == room)
                .OrderByDescending(m => m.CreatedAt)
                .Select(m => new
                {
                    m.Id,
                    m.SenderId,
                    SenderName = m.Sender != null ? m.Sender.FullName : "Unknown",
                    m.Body,
                    m.MessageType,
                    m.CreatedAt
                })
                .FirstOrDefaultAsync();

            var unreadCount = await _db.ChatMessages
                .CountAsync(m => m.RoomKey == room && !m.IsRead && m.SenderId != userId.Value);

            conversations.Add(new
            {
                roomKey = room,
                latestMessage = latest,
                unreadCount
            });
        }

        return Ok(conversations.OrderByDescending(c => ((dynamic)c).latestMessage?.CreatedAt));
    }

    // ── Send via REST (offline fallback) ────────────────────────────────────

    /// <summary>
    /// POST /api/v1/chat/task/{taskId}/send
    /// REST fallback when WebSocket is not available (offline, background).
    /// </summary>
    [HttpPost("task/{taskId}/send")]
    public async Task<IActionResult> SendTaskMessage(Guid taskId, [FromBody] SendChatMessageRequest request)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var sender = await _db.Users.FindAsync(userId.Value);
        if (sender == null) return NotFound(new { message = "Sender not found." });

        var roomKey = $"chat_task_{taskId}";
        var message = new ChatMessage
        {
            TaskId = taskId,
            RoomKey = roomKey,
            SenderId = userId.Value,
            SenderRole = sender.Role,
            Body = request.Body.Trim(),
            MessageType = request.MessageType ?? "text",
            AttachmentUrl = request.AttachmentUrl,
            CreatedAt = DateTime.UtcNow
        };

        _db.ChatMessages.Add(message);
        await _db.SaveChangesAsync();

        // Push via SignalR to anyone already connected
        await _chatHub.Clients.Group(roomKey).SendAsync("NewMessage", new
        {
            message.Id,
            message.SenderId,
            SenderName = sender.FullName,
            message.SenderRole,
            message.Body,
            message.MessageType,
            message.AttachmentUrl,
            message.CreatedAt
        });

        return Ok(message);
    }
}

public record SendChatMessageRequest(string Body, string? MessageType, string? AttachmentUrl);
