using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;
using ShopConnector.Infrastructure.Data;
using System.Security.Claims;

namespace ShopConnector.Api.Hubs;

/// <summary>
/// Real-time chat hub with PostgreSQL message persistence.
/// Supports task-linked threads and direct messages between
/// Customer ↔ Driver ↔ Shopkeeper.
///
/// Groups:
///   • chat_task_{taskId}   — all parties on a specific delivery task
///   • chat_dm_{userA}_{userB}  — direct conversation between two users
///   • presence_{userId}    — user's own presence channel (for read receipts)
/// </summary>
[Authorize]
public class ChatHub : Hub
{
    private readonly CoreDbContext _db;
    private readonly ILogger<ChatHub> _logger;

    public ChatHub(CoreDbContext db, ILogger<ChatHub> logger)
    {
        _db = db;
        _logger = logger;
    }

    // ── Connection Lifecycle ────────────────────────────────────────────────

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        if (userId != null)
        {
            // Auto-join presence group for delivery receipts
            await Groups.AddToGroupAsync(Context.ConnectionId, $"presence_{userId}");
        }
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = GetUserId();
        if (userId != null)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"presence_{userId}");
        }
        await base.OnDisconnectedAsync(exception);
    }

    // ── Room Management ─────────────────────────────────────────────────────

    /// <summary>Join the chat room for a specific task (Customer + Driver + Merchant)</summary>
    public async Task JoinTaskChat(string taskId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"chat_task_{taskId}");

        // Send last 30 messages as history
        var roomKey = $"chat_task_{taskId}";
        var history = await _db.ChatMessages
            .Where(m => m.RoomKey == roomKey)
            .OrderByDescending(m => m.CreatedAt)
            .Take(30)
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

        await Clients.Caller.SendAsync("ChatHistory", history);
    }

    /// <summary>Leave a task chat room</summary>
    public async Task LeaveTaskChat(string taskId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"chat_task_{taskId}");
    }

    /// <summary>Join a direct message channel between two users</summary>
    public async Task JoinDirectChat(string otherUserId)
    {
        var myId = GetUserId();
        if (myId == null) return;

        var roomKey = BuildDmKey(myId.Value.ToString(), otherUserId);
        await Groups.AddToGroupAsync(Context.ConnectionId, roomKey);

        // Send last 30 direct messages as history
        var history = await _db.ChatMessages
            .Where(m => m.RoomKey == roomKey)
            .OrderByDescending(m => m.CreatedAt)
            .Take(30)
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

        await Clients.Caller.SendAsync("ChatHistory", history);
    }

    // ── Messaging ───────────────────────────────────────────────────────────

    /// <summary>
    /// Send a message in a task chat room.
    /// Persists to PostgreSQL and broadcasts to all room members.
    /// </summary>
    public async Task SendTaskMessage(string taskId, string body, string messageType = "text", string? attachmentUrl = null)
    {
        var senderId = GetUserId();
        if (senderId == null)
        {
            await Clients.Caller.SendAsync("Error", new { code = 401, message = "Unauthorized" });
            return;
        }

        var sender = await _db.Users.FindAsync(senderId.Value);
        if (sender == null) return;

        var roomKey = $"chat_task_{taskId}";

        var message = new ChatMessage
        {
            TaskId = Guid.TryParse(taskId, out var tid) ? tid : null,
            RoomKey = roomKey,
            SenderId = senderId.Value,
            SenderRole = sender.Role,
            Body = body.Trim(),
            MessageType = messageType,
            AttachmentUrl = attachmentUrl,
            CreatedAt = DateTime.UtcNow
        };

        _db.ChatMessages.Add(message);
        await _db.SaveChangesAsync();

        var payload = new
        {
            message.Id,
            message.SenderId,
            SenderName = sender.FullName,
            message.SenderRole,
            message.Body,
            message.MessageType,
            message.AttachmentUrl,
            message.CreatedAt
        };

        // Broadcast to all parties in the task chat room
        await Clients.Group(roomKey).SendAsync("NewMessage", payload);

        _logger.LogInformation("[ChatHub] Task {TaskId}: {SenderName} ({Role}) sent: {Body}",
            taskId, sender.FullName, sender.Role, body.Length > 60 ? body[..60] + "…" : body);
    }

    /// <summary>
    /// Send a direct message to another user.
    /// Persists to PostgreSQL, broadcasts to the DM room, and notifies receiver's presence channel.
    /// </summary>
    public async Task SendDirectMessage(string receiverUserId, string body, string messageType = "text", string? attachmentUrl = null)
    {
        var senderId = GetUserId();
        if (senderId == null)
        {
            await Clients.Caller.SendAsync("Error", new { code = 401, message = "Unauthorized" });
            return;
        }

        var sender = await _db.Users.FindAsync(senderId.Value);
        if (sender == null) return;

        var roomKey = BuildDmKey(senderId.Value.ToString(), receiverUserId);

        var message = new ChatMessage
        {
            RoomKey = roomKey,
            SenderId = senderId.Value,
            SenderRole = sender.Role,
            Body = body.Trim(),
            MessageType = messageType,
            AttachmentUrl = attachmentUrl,
            CreatedAt = DateTime.UtcNow
        };

        _db.ChatMessages.Add(message);
        await _db.SaveChangesAsync();

        var payload = new
        {
            message.Id,
            message.SenderId,
            SenderName = sender.FullName,
            message.SenderRole,
            message.Body,
            message.MessageType,
            message.AttachmentUrl,
            message.CreatedAt
        };

        // Send to DM room (both sides) + receiver's presence channel
        await Clients.Group(roomKey).SendAsync("NewMessage", payload);
        await Clients.Group($"presence_{receiverUserId}").SendAsync("IncomingMessage", payload);
    }

    /// <summary>Mark all unread messages in a room as read by this user</summary>
    public async Task MarkRoomAsRead(string roomKey)
    {
        var userId = GetUserId();
        if (userId == null) return;

        var unread = await _db.ChatMessages
            .Where(m => m.RoomKey == roomKey && !m.IsRead && m.SenderId != userId.Value)
            .ToListAsync();

        if (!unread.Any()) return;

        var now = DateTime.UtcNow;
        foreach (var msg in unread)
        {
            msg.IsRead = true;
            msg.ReadAt = now;
        }
        await _db.SaveChangesAsync();

        // Notify sender(s) of read receipts
        foreach (var msg in unread.DistinctBy(m => m.SenderId))
        {
            await Clients.Group($"presence_{msg.SenderId}").SendAsync("MessagesRead", new
            {
                roomKey,
                readBy = userId.Value,
                readAt = now
            });
        }
    }

    /// <summary>Broadcast typing indicator to room members</summary>
    public async Task SendTyping(string roomKey, bool isTyping)
    {
        var userId = GetUserId();
        if (userId == null) return;

        await Clients.OthersInGroup(roomKey).SendAsync("UserTyping", new
        {
            userId = userId.Value,
            isTyping,
            timestamp = DateTime.UtcNow
        });
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private Guid? GetUserId()
    {
        var idStr = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(idStr, out var id) ? id : null;
    }

    /// <summary>
    /// Produces a stable, order-independent DM room key:
    /// dm_{lowerGuid}_{higherGuid}
    /// </summary>
    private static string BuildDmKey(string userA, string userB)
    {
        var sorted = new[] { userA.ToLowerInvariant(), userB.ToLowerInvariant() };
        Array.Sort(sorted);
        return $"chat_dm_{sorted[0]}_{sorted[1]}";
    }
}
