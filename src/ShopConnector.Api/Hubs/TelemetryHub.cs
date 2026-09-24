using Microsoft.AspNetCore.SignalR;

namespace ShopConnector.Api.Hubs;

public class TelemetryHub : Hub
{
    public async Task JoinLiveTracking(string taskId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"tracking_{taskId}");
    }

    public async Task LeaveLiveTracking(string taskId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"tracking_{taskId}");
    }

    public async Task StreamLocation(string taskId, double latitude, double longitude, double speed, double heading)
    {
        await Clients.Group($"tracking_{taskId}").SendAsync("OnLocationUpdate", new
        {
            taskId,
            latitude,
            longitude,
            speed,
            heading,
            timestamp = DateTime.UtcNow
        });
    }
}
