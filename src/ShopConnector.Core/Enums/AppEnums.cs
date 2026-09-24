namespace ShopConnector.Core.Enums;

public enum UserRole
{
    Customer,
    Driver,
    Merchant,
    Dispatcher,
    Admin
}

public enum UserStatus
{
    Active,
    Suspended,
    PendingApproval
}

public enum DriverDutyStatus
{
    OffDuty,
    Free,
    GoingToPickup,
    AtPickup,
    InTransit,
    DropCompleted
}

public enum VehicleType
{
    Bike,
    Auto,
    CabSedan,
    CabSUV,
    TruckMini
}

public enum TaskType
{
    MobilityRide,
    ParcelDelivery,
    GroceryDelivery,
    SchoolTransit
}

public enum PlatformTaskStatus
{
    Created,
    Broadcasting,
    Accepted,
    EnRoutePickup,
    ArrivedPickup,
    InProgress,
    Completed,
    Cancelled
}

public enum TaskAssignmentStatus
{
    Offered,
    Accepted,
    Rejected,
    Expired
}

public enum PaymentMode
{
    Cash,
    Online,
    Dues
}

public enum PaymentStatus
{
    Pending,
    Paid,
    AddedToKhata
}

public enum KhataEntryType
{
    DuesDebit,
    PaymentCredit
}

public enum KhataPaymentMethod
{
    DoorstepCashToDeliveryBoy,
    MerchantCounterCash,
    UPI_Online,
    TaskDuesAdded
}

public enum RfqMode
{
    SingleShop,
    MultiShop,
    BroadcastNetwork
}

public enum RfqStatus
{
    Open,
    QuotesReceived,
    Accepted,
    Expired
}

public enum RfqQuoteStatus
{
    Offered,
    Accepted,
    Rejected,
    Expired
}

public enum MessageChannel
{
    Email,
    SMS,
    WhatsApp,
    PushNotification
}

public enum SubscriptionLogStatus
{
    Scheduled,
    Delivered,
    Paused,
    Failed
}
