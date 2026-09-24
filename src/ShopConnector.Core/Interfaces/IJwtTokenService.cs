using ShopConnector.Core.Entities;

namespace ShopConnector.Core.Interfaces;

public interface IJwtTokenService
{
    string GenerateToken(User user, string deviceId, out DateTime expiresAt);
}
