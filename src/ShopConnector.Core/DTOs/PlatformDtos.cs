using System.ComponentModel.DataAnnotations;
using ShopConnector.Core.Enums;

namespace ShopConnector.Core.DTOs;

// --- Auth DTOs ---
public record LoginPinRequest(
    [Required] string Phone,
    [Required] string Pin,
    [Required] string DeviceId,
    string? DeviceModel,
    string? OsVersion,
    string? AppVersion,
    string? FcmToken
);

public record RegisterRequest(
    [Required] string Phone,
    [Required] string FullName,
    [Required] string Pin,
    [Required] UserRole Role,
    string? Email,
    [Required] string DeviceId,
    string? DeviceModel,
    string? OsVersion,
    string? AppVersion
);

public record AuthResponse(
    Guid UserId,
    string Phone,
    string FullName,
    string Role,
    string Token,
    DateTime ExpiresAt,
    string DeviceId
);

// --- Driver DTOs ---
public record UpdateDutyStatusRequest(
    [Required] DriverDutyStatus Status,
    [Required] string DeviceId
);

public record UpdateRadiusRequest(
    [Range(0.5, 50.0)] decimal AcceptanceRadiusKm,
    [Range(1.0, 100.0)] decimal DeliveryRadiusKm
);

public record AddVehicleRequest(
    [Required] string Make,
    [Required] string Model,
    [Required] string PlateNumber,
    [Required] VehicleType VehicleType
);

public record CreateIntercityBannerRequest(
    [Required] string FromCity,
    [Required] string ToCity,
    [Required] DateTime DepartureTime,
    [Range(1, 10)] int SeatsAvailable,
    [Range(10, 100000)] decimal ExpectedPrice
);

// --- Business & Catalog DTOs ---
public record CreateBusinessRequest(
    [Required] string Name,
    [Required] string Category,
    [Required] string Phone,
    [Required] string Address,
    double Latitude,
    double Longitude,
    TimeSpan? OpenTime,
    TimeSpan? CloseTime
);

public record UpdateBusinessSettingsRequest(
    bool DuesEnabledGlobally,
    string AllowedPaymentModes
);

public record CreateCatalogItemRequest(
    [Required] string Name,
    string Category,
    decimal Price,
    string Unit,
    string? ImageUrl
);

// --- Khata DTOs ---
public record UpdateKhataPermissionRequest(
    bool IsDuesAllowed,
    decimal CreditLimit
);

public record CreateKhataTransactionRequest(
    [Required] Guid BusinessId,
    [Required] Guid CustomerId,
    Guid? TaskId,
    [Required] KhataEntryType EntryType,
    [Required] decimal Amount,
    [Required] KhataPaymentMethod PaymentMethod,
    string? Notes
);

// --- Tasks DTOs ---
public record EstimateTaskRequest(
    double PickupLatitude,
    double PickupLongitude,
    double DropoffLatitude,
    double DropoffLongitude,
    TaskType TaskType
);

public record TaskEstimateResponse(
    decimal DistanceKm,
    int DurationMinutes,
    decimal EstimatedFare,
    string Provider
);

public record CreateTaskRequest(
    [Required] TaskType TaskType,
    Guid? BusinessId,
    [Required] string PickupAddress,
    double PickupLatitude,
    double PickupLongitude,
    [Required] string DropoffAddress,
    double DropoffLatitude,
    double DropoffLongitude,
    [Required] PaymentMode PaymentMode,
    string? OrderItemsJson
);

public record AcceptTaskRequest(
    [Required] string DeviceId
);

public record VerifyOtpRequest(
    [Required] string Otp,
    [Required] string DeviceId
);

// --- RFQ DTOs ---
public record CreateRfqRequest(
    [Required] RfqMode Mode,
    [Required] string RawPrompt,
    string? StructuredItemsJson,
    double DeliveryLatitude,
    double DeliveryLongitude,
    [Required] string DeliveryAddress,
    List<Guid>? TargetBusinessIds
);

public record SubmitQuoteRequest(
    [Required] decimal QuotedTotalPrice,
    string? QuoteDetailsJson,
    int EstimatedPrepMinutes
);

// --- Subscription DTOs ---
public record CreateSubscriptionRequest(
    [Required] Guid BusinessId,
    [Required] string ItemName,
    decimal Quantity,
    string Unit,
    string DeliverySlot,
    string DaysOfWeek,
    decimal PricePerDelivery
);

public record PauseSubscriptionRequest(
    [Required] DateOnly PauseStartDate,
    [Required] DateOnly PauseEndDate,
    string? Reason
);

// --- Social & Classifieds DTOs ---
public record CreateSocialMeetupRequest(
    [Required] string Category,
    [Required] string Title,
    string Description,
    [Required] DateTime ProposedTime,
    [Required] string LocationName,
    double Latitude,
    double Longitude
);

public record CreateClassifiedRequest(
    [Required] string Category,
    [Required] string Title,
    string Description,
    decimal? Budget,
    [Required] string LocationName,
    double Latitude,
    double Longitude
);

// --- Telemetry DTOs ---
public record DriverGpsPingRequest(
    [Required] string DeviceId,
    double Latitude,
    double Longitude,
    double? Altitude,
    double Heading,
    double Speed,
    double Accuracy,
    int BatteryPct,
    bool IsCharging
);
