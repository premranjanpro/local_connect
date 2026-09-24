using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using ShopConnector.Core.Enums;
using ShopConnector.Core.Interfaces;

namespace ShopConnector.Infrastructure.Services;

public class FcmNotificationService : IFcmNotificationService
{
    private readonly IConfiguration _configuration;
    private readonly IAuditService _auditService;
    private readonly ILogger<FcmNotificationService> _logger;
    private readonly bool _isFirebaseInitialized;

    public FcmNotificationService(
        IConfiguration configuration,
        IAuditService auditService,
        ILogger<FcmNotificationService> logger)
    {
        _configuration = configuration;
        _auditService = auditService;
        _logger = logger;

        try
        {
            if (FirebaseApp.DefaultInstance == null)
            {
                var credPath = _configuration["Firebase:CredentialsPath"];
                if (!string.IsNullOrEmpty(credPath) && File.Exists(credPath))
                {
                    FirebaseApp.Create(new AppOptions
                    {
                        Credential = GoogleCredential.FromFile(credPath)
                    });
                    _isFirebaseInitialized = true;
                    _logger.LogInformation("Firebase Admin SDK successfully initialized using: {Path}", credPath);
                }
                else
                {
                    _isFirebaseInitialized = false;
                    _logger.LogInformation("Firebase credentials not supplied. Running FCM in Simulation Mode.");
                }
            }
            else
            {
                _isFirebaseInitialized = true;
            }
        }
        catch (Exception ex)
        {
            _isFirebaseInitialized = false;
            _logger.LogWarning(ex, "Could not initialize Firebase Admin SDK. Falling back to Simulation Mode.");
        }
    }

    public async Task<bool> SendPushNotificationAsync(
        Guid? recipientUserId,
        string fcmToken,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        if (string.IsNullOrWhiteSpace(fcmToken))
        {
            _logger.LogWarning("Cannot send push notification: FCM token is null or empty.");
            return false;
        }

        string status = "Sent";
        string? errorMessage = null;

        if (_isFirebaseInitialized)
        {
            try
            {
                var message = new Message
                {
                    Token = fcmToken,
                    Notification = new Notification
                    {
                        Title = title,
                        Body = body
                    },
                    Data = data
                };

                var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                _logger.LogInformation("FCM Push sent successfully. Response: {Response}", response);
            }
            catch (Exception ex)
            {
                status = "Failed";
                errorMessage = ex.Message;
                _logger.LogError(ex, "Failed to send FCM push to token: {Token}", fcmToken);
            }
        }
        else
        {
            _logger.LogInformation("[FCM SIMULATED PUSH] To: {Token} | Title: {Title} | Body: {Body}", fcmToken, title, body);
        }

        // Log push event in message_dispatch_logs table
        await _auditService.LogMessageAsync(
            recipientUserId,
            MessageChannel.PushNotification,
            fcmToken,
            title,
            body,
            status,
            errorMessage
        );

        return status == "Sent";
    }

    public async Task<int> SendMulticastPushNotificationAsync(
        List<string> fcmTokens,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        if (fcmTokens == null || fcmTokens.Count == 0) return 0;

        int successCount = 0;
        foreach (var token in fcmTokens.Distinct())
        {
            var sent = await SendPushNotificationAsync(null, token, title, body, data);
            if (sent) successCount++;
        }

        return successCount;
    }

    public async Task<bool> SendTopicNotificationAsync(
        string topic,
        string title,
        string body,
        Dictionary<string, string>? data = null)
    {
        string status = "Sent";
        string? errorMessage = null;

        if (_isFirebaseInitialized)
        {
            try
            {
                var message = new Message
                {
                    Topic = topic,
                    Notification = new Notification
                    {
                        Title = title,
                        Body = body
                    },
                    Data = data
                };

                var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                _logger.LogInformation("FCM Topic push sent to {Topic}: {Response}", topic, response);
            }
            catch (Exception ex)
            {
                status = "Failed";
                errorMessage = ex.Message;
                _logger.LogError(ex, "Failed to send FCM topic message to {Topic}", topic);
            }
        }
        else
        {
            _logger.LogInformation("[FCM SIMULATED TOPIC PUSH] Topic: {Topic} | Title: {Title} | Body: {Body}", topic, title, body);
        }

        await _auditService.LogMessageAsync(
            null,
            MessageChannel.PushNotification,
            $"topic://{topic}",
            title,
            body,
            status,
            errorMessage
        );

        return status == "Sent";
    }
}
