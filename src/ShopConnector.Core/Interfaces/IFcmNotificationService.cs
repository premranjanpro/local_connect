namespace ShopConnector.Core.Interfaces;

public interface IFcmNotificationService
{
    Task<bool> SendPushNotificationAsync(
        Guid? recipientUserId,
        string fcmToken,
        string title,
        string body,
        Dictionary<string, string>? data = null
    );

    Task<int> SendMulticastPushNotificationAsync(
        List<string> fcmTokens,
        string title,
        string body,
        Dictionary<string, string>? data = null
    );

    Task<bool> SendTopicNotificationAsync(
        string topic,
        string title,
        string body,
        Dictionary<string, string>? data = null
    );
}
