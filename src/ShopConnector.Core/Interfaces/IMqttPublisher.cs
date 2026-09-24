namespace ShopConnector.Core.Interfaces;

public interface IMqttPublisher
{
    Task PublishAsync(string topic, object payload, CancellationToken cancellationToken = default);
    bool IsConnected { get; }
}
