namespace ShopConnector.Core.Interfaces;

public interface ILiveKitService
{
    string GenerateAccessToken(string roomName, string identity, string name, bool canPublish = true, bool canSubscribe = true);
    string GetLiveKitUrl();
}
