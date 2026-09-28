namespace ShopConnector.Api.Services;

/// <summary>
/// Haversine geofence checker for delivery event validation.
/// Used to verify driver was actually at the pickup/drop location
/// when they submitted an OTP or status change event.
///
/// Platform thresholds (Skill § Point 8):
///   OK      : 0-150m     — driver clearly at location
///   WARNING : 150-400m   — possible GPS drift, log yellow alert
///   ALERT   : 400m+      — driver was NOT at location, RED ALERT to shop owner
/// </summary>
public static class GeofenceHelper
{
    private const double EarthRadiusMeters = 6_371_000.0;
    private const double OkRadiusMeters = 150.0;
    private const double WarningRadiusMeters = 400.0;

    /// <summary>Haversine distance between two GPS coords in meters.</summary>
    public static double DistanceMeters(double lat1, double lng1, double lat2, double lng2)
    {
        var dLat = ToRad(lat2 - lat1);
        var dLng = ToRad(lng2 - lng1);
        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2)
              + Math.Cos(ToRad(lat1)) * Math.Cos(ToRad(lat2))
              * Math.Sin(dLng / 2) * Math.Sin(dLng / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return EarthRadiusMeters * c;
    }

    /// <summary>
    /// Evaluates geofence status given driver coords and expected point coords.
    /// Returns (GeofenceStatus, DistanceMeters).
    /// </summary>
    public static (string Status, double DistanceMeters) Evaluate(
        double driverLat, double driverLng,
        double expectedLat, double expectedLng)
    {
        var dist = DistanceMeters(driverLat, driverLng, expectedLat, expectedLng);

        var status = dist <= OkRadiusMeters ? "OK"
                   : dist <= WarningRadiusMeters ? "WARNING"
                   : "ALERT";

        return (status, dist);
    }

    /// <summary>Human-readable alert message for shop owner.</summary>
    public static string AlertMessage(string status, double distanceMeters, string eventType) => status switch
    {
        "OK" => $"✅ Driver was within {distanceMeters:F0}m of {eventType} point. Verified.",
        "WARNING" => $"⚠️ Driver was {distanceMeters:F0}m from {eventType} point (expected <150m). Possible GPS drift.",
        "ALERT" => $"🚨 RED ALERT: Driver was {distanceMeters:F0}m from {eventType} point! Driver may NOT have been at location. Investigate.",
        _ => "N/A"
    };

    private static double ToRad(double deg) => deg * (Math.PI / 180.0);
}
