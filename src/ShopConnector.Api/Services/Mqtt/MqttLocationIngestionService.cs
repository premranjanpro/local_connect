using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MQTTnet;
using MQTTnet.Client;
using MQTTnet.Protocol;
using ShopConnector.Api.Hubs;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;

namespace ShopConnector.Api.Services.Mqtt;

public class MqttLocationIngestionService : BackgroundService, IMqttPublisher
{
    private readonly ILogger<MqttLocationIngestionService> _logger;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IHubContext<TelemetryHub> _telemetryHub;
    private readonly MqttOptions _options;
    private IMqttClient? _mqttClient;
    private bool _isConnected;

    public bool IsConnected => _isConnected && _mqttClient != null && _mqttClient.IsConnected;

    public MqttLocationIngestionService(
        ILogger<MqttLocationIngestionService> logger,
        IServiceScopeFactory scopeFactory,
        IHubContext<TelemetryHub> telemetryHub,
        IOptions<MqttOptions> options)
    {
        _logger = logger;
        _scopeFactory = scopeFactory;
        _telemetryHub = telemetryHub;
        _options = options.Value;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("[MQTT Ingestion] Starting MQTT Telemetry Ingestion Service targeting {Host}:{Port}...", _options.Host, _options.Port);

        var factory = new MqttFactory();

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                _mqttClient = factory.CreateMqttClient();

                var clientOptions = new MqttClientOptionsBuilder()
                    .WithTcpServer(_options.Host, _options.Port)
                    .WithClientId($"{_options.ClientId}_{Guid.NewGuid().ToString("N")[..8]}")
                    .WithCleanSession()
                    .WithTimeout(TimeSpan.FromSeconds(10))
                    .Build();

                _mqttClient.ApplicationMessageReceivedAsync += HandleIncomingMessageAsync;

                _mqttClient.DisconnectedAsync += e =>
                {
                    _isConnected = false;
                    _logger.LogWarning("[MQTT Ingestion] Disconnected from broker ({Reason}). Will retry...", e.Reason);
                    return Task.CompletedTask;
                };

                _logger.LogInformation("[MQTT Ingestion] Connecting to Mosquitto at {Host}:{Port}...", _options.Host, _options.Port);
                var connectResult = await _mqttClient.ConnectAsync(clientOptions, stoppingToken);

                if (connectResult.ResultCode == MqttClientConnectResultCode.Success)
                {
                    _isConnected = true;
                    _logger.LogInformation("[MQTT Ingestion] Successfully connected to Mosquitto MQTT broker!");

                    // Subscribe to configured telemetry and tracking topics
                    foreach (var topic in _options.SubscribeTopics)
                    {
                        var subscribeOptions = factory.CreateSubscribeOptionsBuilder()
                            .WithTopicFilter(f => f.WithTopic(topic).WithQualityOfServiceLevel(MqttQualityOfServiceLevel.AtLeastOnce))
                            .Build();

                        await _mqttClient.SubscribeAsync(subscribeOptions, stoppingToken);
                        _logger.LogInformation("[MQTT Ingestion] Subscribed to topic: {Topic}", topic);
                    }

                    // Keep running while connected
                    while (!stoppingToken.IsCancellationRequested && _mqttClient.IsConnected)
                    {
                        await Task.Delay(5000, stoppingToken);
                    }
                }
                else
                {
                    _logger.LogWarning("[MQTT Ingestion] Connect failed with code {Code}. Retrying in 5 seconds...", connectResult.ResultCode);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _isConnected = false;
                _logger.LogError(ex, "[MQTT Ingestion] Error connecting or operating MQTT client. Retrying in 5s...");
            }

            try
            {
                if (_mqttClient != null)
                {
                    await _mqttClient.DisconnectAsync(cancellationToken: CancellationToken.None);
                    _mqttClient.Dispose();
                    _mqttClient = null;
                }
            }
            catch { /* Ignore cleanup exceptions */ }

            await Task.Delay(5000, stoppingToken);
        }

        _logger.LogInformation("[MQTT Ingestion] Stopped MQTT Ingestion Service.");
    }

    private async Task HandleIncomingMessageAsync(MqttApplicationMessageReceivedEventArgs e)
    {
        var topic = e.ApplicationMessage.Topic;
        var payloadBytes = e.ApplicationMessage.PayloadSegment.ToArray();
        var payload = Encoding.UTF8.GetString(payloadBytes);

        _logger.LogDebug("[MQTT Ingestion] Received message on topic {Topic}: {Payload}", topic, payload);

        try
        {
            using var doc = JsonDocument.Parse(payload);
            var root = doc.RootElement;

            // Extract DriverId either from JSON or topic (e.g. driver/{driverId}/location)
            Guid driverId = Guid.Empty;
            if (root.TryGetProperty("driverId", out var dIdProp) || root.TryGetProperty("DriverId", out dIdProp))
            {
                Guid.TryParse(dIdProp.GetString(), out driverId);
            }
            if (driverId == Guid.Empty)
            {
                // Attempt extraction from topic segments: driver/{id}/location
                var segments = topic.Split('/');
                if (segments.Length >= 2 && Guid.TryParse(segments[1], out var parsedId))
                {
                    driverId = parsedId;
                }
            }

            if (driverId == Guid.Empty)
            {
                _logger.LogWarning("[MQTT Ingestion] Received location ping on {Topic} without valid DriverId.", topic);
                return;
            }

            // Extract TaskId if present
            Guid? taskId = null;
            if (root.TryGetProperty("taskId", out var tIdProp) || root.TryGetProperty("TaskId", out tIdProp))
            {
                if (Guid.TryParse(tIdProp.GetString(), out var parsedTaskId))
                {
                    taskId = parsedTaskId;
                }
            }

            // Extract coordinates & telemetry metrics
            double lat = 0.0, lng = 0.0, speed = 0.0, heading = 0.0, accuracy = 5.0;
            int batteryPct = 100;
            bool isCharging = false;
            string deviceId = "mqtt_telemetry_device";

            if (root.TryGetProperty("lat", out var latProp) || root.TryGetProperty("latitude", out latProp) || root.TryGetProperty("Latitude", out latProp))
                lat = latProp.GetDouble();

            if (root.TryGetProperty("lng", out var lngProp) || root.TryGetProperty("longitude", out lngProp) || root.TryGetProperty("Longitude", out lngProp))
                lng = lngProp.GetDouble();

            if (root.TryGetProperty("speed", out var spdProp) || root.TryGetProperty("Speed", out spdProp))
                speed = spdProp.GetDouble();

            if (root.TryGetProperty("heading", out var hdgProp) || root.TryGetProperty("Heading", out hdgProp))
                heading = hdgProp.GetDouble();

            if (root.TryGetProperty("accuracy", out var accProp) || root.TryGetProperty("Accuracy", out accProp))
                accuracy = accProp.GetDouble();

            if (root.TryGetProperty("batteryPct", out var batProp) || root.TryGetProperty("battery", out batProp) || root.TryGetProperty("BatteryPct", out batProp))
                batteryPct = batProp.GetInt32();

            if (root.TryGetProperty("isCharging", out var chgProp) || root.TryGetProperty("IsCharging", out chgProp))
                isCharging = chgProp.GetBoolean();

            if (root.TryGetProperty("deviceId", out var devProp) || root.TryGetProperty("DeviceId", out devProp))
                deviceId = devProp.GetString() ?? deviceId;

            // Ingest into TelemetryDb & CoreDb via Scoped DbContexts
            using (var scope = _scopeFactory.CreateScope())
            {
                var telemetryDb = scope.ServiceProvider.GetRequiredService<TelemetryDbContext>();
                var coreDb = scope.ServiceProvider.GetRequiredService<CoreDbContext>();

                // 1. Append to driver_gps_pings
                var ping = new DriverGpsPing
                {
                    DriverId = driverId,
                    DeviceId = deviceId,
                    Latitude = lat,
                    Longitude = lng,
                    Heading = heading,
                    Speed = speed,
                    Accuracy = accuracy,
                    BatteryPct = batteryPct,
                    IsCharging = isCharging,
                    Timestamp = DateTime.UtcNow
                };
                telemetryDb.DriverGpsPings.Add(ping);

                // 2. Upsert driver_location_current
                var current = await telemetryDb.DriverLocationCurrent.FindAsync(driverId);
                if (current == null)
                {
                    current = new DriverLocationCurrent
                    {
                        DriverId = driverId,
                        DeviceId = deviceId,
                        Latitude = lat,
                        Longitude = lng,
                        Heading = heading,
                        Speed = speed,
                        DutyStatus = taskId.HasValue ? "ActiveTask" : "OnDuty",
                        UpdatedAt = DateTime.UtcNow
                    };
                    telemetryDb.DriverLocationCurrent.Add(current);
                }
                else
                {
                    current.DeviceId = deviceId;
                    current.Latitude = lat;
                    current.Longitude = lng;
                    current.Heading = heading;
                    current.Speed = speed;
                    if (taskId.HasValue) current.DutyStatus = "ActiveTask";
                    current.UpdatedAt = DateTime.UtcNow;
                }

                // 3. Update DriverProfile heartbeat & coords in CoreDb
                var profile = await coreDb.DriverProfiles.FirstOrDefaultAsync(p => p.UserId == driverId);
                if (profile != null)
                {
                    profile.CurrentLatitude = lat;
                    profile.CurrentLongitude = lng;
                    profile.CurrentHeading = heading;
                    profile.CurrentSpeed = speed;
                    profile.BatteryPct = batteryPct;
                    profile.IsCharging = isCharging;
                    profile.LastHeartbeatAt = DateTime.UtcNow;
                }

                await telemetryDb.SaveChangesAsync();
                await coreDb.SaveChangesAsync();
            }

            // 4. Relay to SignalR TelemetryHub for instant Flutter Map & Web Dashboard real-time animation
            var updatePayload = new
            {
                driverId,
                taskId = taskId?.ToString(),
                latitude = lat,
                longitude = lng,
                speed,
                heading,
                accuracy,
                timestamp = DateTime.UtcNow
            };

            if (taskId.HasValue)
            {
                await _telemetryHub.Clients.Group($"tracking_{taskId}").SendAsync("OnLocationUpdate", updatePayload);
                // Also publish live MQTT tracking topic for task subscribers: tasks/{taskId}/tracking
                await PublishAsync($"tasks/{taskId}/tracking", updatePayload);
            }

            await _telemetryHub.Clients.Group($"driver_{driverId}").SendAsync("OnLocationUpdate", updatePayload);
            await _telemetryHub.Clients.Group("AdminGroup").SendAsync("OnDriverMoved", updatePayload);

            _logger.LogInformation(
                "[MQTT Ingestion] Ingested Ping | Driver={DriverId} Task={TaskId} Lat={Lat:F5} Lng={Lng:F5} Speed={Speed:F1} km/h",
                driverId,
                taskId?.ToString() ?? "None",
                lat,
                lng,
                speed);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MQTT Ingestion] Error processing MQTT location payload on topic {Topic}", topic);
        }
    }

    public async Task PublishAsync(string topic, object payload, CancellationToken cancellationToken = default)
    {
        if (_mqttClient == null || !_mqttClient.IsConnected)
        {
            _logger.LogWarning("[MQTT Ingestion] Publish skipped for {Topic}: MQTT client is not connected to Mosquitto.", topic);
            return;
        }

        try
        {
            var json = JsonSerializer.Serialize(payload);
            var message = new MqttApplicationMessageBuilder()
                .WithTopic(topic)
                .WithPayload(Encoding.UTF8.GetBytes(json))
                .WithQualityOfServiceLevel(MqttQualityOfServiceLevel.AtLeastOnce)
                .WithRetainFlag(false)
                .Build();

            await _mqttClient.PublishAsync(message, cancellationToken);
            _logger.LogDebug("[MQTT Ingestion] Published message to {Topic}", topic);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "[MQTT Ingestion] Failed to publish message to {Topic}", topic);
        }
    }
}
