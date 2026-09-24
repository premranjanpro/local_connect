using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using ShopConnector.Core.Entities;
using ShopConnector.Core.Interfaces;

namespace ShopConnector.Infrastructure.Services;

public class JwtTokenService : IJwtTokenService
{
    private readonly IConfiguration _configuration;

    public JwtTokenService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public string GenerateToken(User user, string deviceId, out DateTime expiresAt)
    {
        var secret = _configuration["Jwt:SecretKey"] ?? "ShopConnectorUltraSecureSecretKey2026!LongEnoughForSha256Signature";
        var issuer = _configuration["Jwt:Issuer"] ?? "ShopConnectorApi";
        var audience = _configuration["Jwt:Audience"] ?? "ShopConnectorApp";
        var expirationHours = int.TryParse(_configuration["Jwt:ExpirationHours"], out var h) ? h : 720; // 30 days

        expiresAt = DateTime.UtcNow.AddHours(expirationHours);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.MobilePhone, user.Phone),
            new(ClaimTypes.Name, user.FullName),
            new(ClaimTypes.Role, user.Role),
            new("device_id", deviceId)
        };

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: issuer,
            audience: audience,
            claims: claims,
            expires: expiresAt,
            signingCredentials: creds
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
