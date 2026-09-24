namespace ShopConnector.Api.Services.Mqtt;

public class MqttOptions
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 1883;
    public string ClientId { get; set; } = "ShopConnector_Backend_Api";
    public string Username { get; set; } = "";
    public string Password { get; set; } = "";
    public string[] SubscribeTopics { get; set; } = new[]
    {
        "driver/+/location",
        "drivers/+/location",
        "tasks/+/location",
        "tracking/+/location"
    };
}
