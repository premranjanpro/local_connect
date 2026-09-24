using ShopConnector.Core.Interfaces;

namespace ShopConnector.Infrastructure.Services;

public class HaversineDistanceService : IDistanceMatrixService
{
    private const double EarthRadiusKm = 6371.0;
    private const decimal UrbanTortuosityFactor = 1.30m; // Indian urban road bends
    private const double AverageCitySpeedKmh = 25.0; // 25 km/h urban traffic speed
    private const int TrafficBufferMinutes = 3;

    public Task<DistanceCalculationResult> CalculateDistanceAsync(
        double originLat,
        double originLng,
        double destLat,
        double destLng)
    {
        // 1. Calculate Great-Circle Distance via Haversine Formula
        double dLat = ToRadians(destLat - originLat);
        double dLon = ToRadians(destLng - originLng);

        double lat1Rad = ToRadians(originLat);
        double lat2Rad = ToRadians(destLat);

        double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                   Math.Cos(lat1Rad) * Math.Cos(lat2Rad) *
                   Math.Sin(dLon / 2) * Math.Sin(dLon / 2);

        double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        double straightLineKm = EarthRadiusKm * c;

        // 2. Apply Urban Tortuosity Multiplier (1.30x road distance)
        decimal estimatedRoadDistanceKm = Math.Round((decimal)straightLineKm * UrbanTortuosityFactor, 2);
        if (estimatedRoadDistanceKm < 0.20m)
        {
            estimatedRoadDistanceKm = 0.20m; // Minimum dispatch distance floor
        }

        // 3. Estimate Duration in Minutes
        double travelHours = (double)estimatedRoadDistanceKm / AverageCitySpeedKmh;
        int durationMinutes = (int)Math.Ceiling(travelHours * 60) + TrafficBufferMinutes;

        return Task.FromResult(new DistanceCalculationResult(
            DistanceKm: estimatedRoadDistanceKm,
            DurationMinutes: durationMinutes,
            Provider: "Haversine_UrbanEngine_v1"
        ));
    }

    private static double ToRadians(double degrees) => degrees * (Math.PI / 180.0);
}
