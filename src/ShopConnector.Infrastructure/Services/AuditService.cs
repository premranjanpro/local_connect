using ShopConnector.Core.Entities;
using ShopConnector.Core.Enums;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Infrastructure.Services;

public class AuditService : IAuditService
{
    private readonly CoreDbContext _dbContext;

    public AuditService(CoreDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public async Task LogActionAsync(
        Guid? userId,
        string action,
        string entityType,
        string entityId,
        string? ipAddress = null,
        string? deviceId = null,
        string? details = null)
    {
        try
        {
            var log = new AuditActionLog
            {
                UserId = userId,
                Action = action,
                EntityType = entityType,
                EntityId = entityId,
                IpAddress = ipAddress,
                DeviceId = deviceId,
                Details = details,
                CreatedAt = DateTime.UtcNow
            };

            _dbContext.AuditActionLogs.Add(log);
            await _dbContext.SaveChangesAsync();
        }
        catch
        {
            // Do not fail primary request if audit logging fails
        }
    }

    public async Task LogMessageAsync(
        Guid? recipientUserId,
        MessageChannel channel,
        string recipientAddress,
        string? subjectOrTitle,
        string body,
        string status = "Sent",
        string? errorMessage = null)
    {
        try
        {
            var log = new MessageDispatchLog
            {
                RecipientUserId = recipientUserId,
                Channel = channel.ToString(),
                RecipientAddress = recipientAddress,
                SubjectOrTitle = subjectOrTitle,
                Body = body,
                Status = status,
                ErrorMessage = errorMessage,
                CreatedAt = DateTime.UtcNow
            };

            _dbContext.MessageDispatchLogs.Add(log);
            await _dbContext.SaveChangesAsync();
        }
        catch
        {
            // Do not fail primary request if message audit logging fails
        }
    }
}
