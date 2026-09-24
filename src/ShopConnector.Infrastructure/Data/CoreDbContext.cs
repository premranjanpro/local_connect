using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;

namespace ShopConnector.Infrastructure.Data;

public class CoreDbContext : DbContext
{
    public CoreDbContext(DbContextOptions<CoreDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserDeviceSession> UserDeviceSessions => Set<UserDeviceSession>();
    public DbSet<DriverProfile> DriverProfiles => Set<DriverProfile>();
    public DbSet<Vehicle> Vehicles => Set<Vehicle>();
    public DbSet<DriverIntercityBanner> DriverIntercityBanners => Set<DriverIntercityBanner>();
    public DbSet<Business> Businesses => Set<Business>();
    public DbSet<CatalogItem> CatalogItems => Set<CatalogItem>();
    public DbSet<CustomerRfq> CustomerRfqs => Set<CustomerRfq>();
    public DbSet<RfqBusinessQuote> RfqBusinessQuotes => Set<RfqBusinessQuote>();
    public DbSet<TaskEntity> Tasks => Set<TaskEntity>();
    public DbSet<TaskAssignment> TaskAssignments => Set<TaskAssignment>();
    public DbSet<KhataCustomerSetting> KhataCustomerSettings => Set<KhataCustomerSetting>();
    public DbSet<KhataLedgerEntry> KhataLedgerEntries => Set<KhataLedgerEntry>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<SubscriptionPause> SubscriptionPauses => Set<SubscriptionPause>();
    public DbSet<SubscriptionDailyLog> SubscriptionDailyLogs => Set<SubscriptionDailyLog>();
    public DbSet<SchoolTransitSchedule> SchoolTransitSchedules => Set<SchoolTransitSchedule>();
    public DbSet<SocialMeetup> SocialMeetups => Set<SocialMeetup>();
    public DbSet<CommunityClassified> CommunityClassifieds => Set<CommunityClassified>();
    public DbSet<AuditActionLog> AuditActionLogs => Set<AuditActionLog>();
    public DbSet<MessageDispatchLog> MessageDispatchLogs => Set<MessageDispatchLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User
        modelBuilder.Entity<User>()
            .HasIndex(u => u.Phone)
            .IsUnique();

        // Driver Profile
        modelBuilder.Entity<DriverProfile>()
            .HasIndex(d => d.UserId)
            .IsUnique();

        modelBuilder.Entity<DriverProfile>()
            .HasOne(d => d.User)
            .WithOne(u => u.DriverProfile)
            .HasForeignKey<DriverProfile>(d => d.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        // Vehicle
        modelBuilder.Entity<Vehicle>()
            .HasOne(v => v.Driver)
            .WithMany(u => u.Vehicles)
            .HasForeignKey(v => v.DriverId)
            .OnDelete(DeleteBehavior.Cascade);

        // Business
        modelBuilder.Entity<Business>()
            .HasOne(b => b.Merchant)
            .WithMany(u => u.Businesses)
            .HasForeignKey(b => b.MerchantId)
            .OnDelete(DeleteBehavior.Cascade);

        // CatalogItem
        modelBuilder.Entity<CatalogItem>()
            .HasOne(c => c.Business)
            .WithMany(b => b.CatalogItems)
            .HasForeignKey(c => c.BusinessId)
            .OnDelete(DeleteBehavior.Cascade);

        // Task Entity
        modelBuilder.Entity<TaskEntity>()
            .HasIndex(t => t.Status);

        modelBuilder.Entity<TaskEntity>()
            .HasIndex(t => t.CustomerId);

        modelBuilder.Entity<TaskEntity>()
            .HasIndex(t => t.AssignedDriverId);

        // Task Assignment
        modelBuilder.Entity<TaskAssignment>()
            .HasOne(ta => ta.Task)
            .WithMany(t => t.Assignments)
            .HasForeignKey(ta => ta.TaskId)
            .OnDelete(DeleteBehavior.Cascade);

        // Khata Customer Setting
        modelBuilder.Entity<KhataCustomerSetting>()
            .HasIndex(k => new { k.BusinessId, k.CustomerId })
            .IsUnique();

        // Khata Ledger Entry
        modelBuilder.Entity<KhataLedgerEntry>()
            .HasIndex(k => new { k.BusinessId, k.CustomerId });

        // Subscriptions
        modelBuilder.Entity<Subscription>()
            .HasIndex(s => new { s.CustomerId, s.BusinessId });

        // Audit Logs
        modelBuilder.Entity<AuditActionLog>()
            .HasIndex(a => a.UserId);

        modelBuilder.Entity<AuditActionLog>()
            .HasIndex(a => a.CreatedAt);

        // Message Dispatch Logs
        modelBuilder.Entity<MessageDispatchLog>()
            .HasIndex(m => m.RecipientUserId);
    }
}
