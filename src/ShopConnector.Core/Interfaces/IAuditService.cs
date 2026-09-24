using ShopConnector.Core.Enums;

namespace ShopConnector.Core.Interfaces;

public interface IAuditService
{
    Task LogActionAsync(
        Guid? userId,
        string action,
        string entityType,
        string entityId,
        string? ipAddress = null,
        string? deviceId = null,
        string? details = null
    );

    Task LogMessageAsync(
        Guid? recipientUserId,
        MessageChannel channel,
        string recipientAddress,
        string? subjectOrTitle,
        string body,
        string status = "Sent",
        string? errorMessage = null
    );
}
