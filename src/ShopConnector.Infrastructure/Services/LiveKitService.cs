using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using ShopConnector.Core.Interfaces;

namespace ShopConnector.Infrastructure.Services;

public class LiveKitService : ILiveKitService
{
    private readonly string _apiKey;
    private readonly string _apiSecret;
    private readonly string _serverUrl;

    public LiveKitService(IConfiguration configuration)
    {
        _apiKey = configuration["LiveKit:ApiKey"] ?? "devkey";
        _apiSecret = configuration["LiveKit:ApiSecret"] ?? "secretsecretsecretsecretsecretsecret";
        _serverUrl = configuration["LiveKit:ServerUrl"] ?? "ws://127.0.0.1:7880";
    }

    public string GetLiveKitUrl() => _serverUrl;

    public string GenerateAccessToken(string roomName, string identity, string name, bool canPublish = true, bool canSubscribe = true)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var key = Encoding.UTF8.GetBytes(_apiSecret);

        var videoGrants = new Dictionary<string, object>
        {
            { "room", roomName },
            { "roomJoin", true },
            { "canPublish", canPublish },
            { "canSubscribe", canSubscribe },
            { "canPublishData", true }
        };

        var claims = new List<Claim>
        {
            new Claim("sub", identity),
            new Claim("name", name),
            new Claim("iss", _apiKey),
            new Claim("video", JsonSerializer.Serialize(videoGrants), JsonClaimValueTypes.Json)
        };

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Issuer = _apiKey,
            Expires = DateTime.UtcNow.AddHours(12),
            SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256)
        };

        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}
