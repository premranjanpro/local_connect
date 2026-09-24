namespace ShopConnector.Core.Interfaces;

public record DistanceCalculationResult(
    decimal DistanceKm,
    int DurationMinutes,
    string Provider
);

public interface IDistanceMatrixService
{
    Task<DistanceCalculationResult> CalculateDistanceAsync(
        double originLat,
        double originLng,
        double destLat,
        double destLng
    );
}
