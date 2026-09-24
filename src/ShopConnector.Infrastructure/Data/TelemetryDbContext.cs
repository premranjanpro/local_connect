using Microsoft.EntityFrameworkCore;
using ShopConnector.Core.Entities;

namespace ShopConnector.Infrastructure.Data;

public class TelemetryDbContext : DbContext
{
    public TelemetryDbContext(DbContextOptions<TelemetryDbContext> options) : base(options)
    {
    }

    public DbSet<DriverGpsPing> DriverGpsPings => Set<DriverGpsPing>();
    public DbSet<DriverLocationCurrent> DriverLocationCurrent => Set<DriverLocationCurrent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<DriverGpsPing>()
            .HasIndex(p => new { p.DriverId, p.Timestamp });

        modelBuilder.Entity<DriverLocationCurrent>()
            .HasKey(c => c.DriverId);
    }
}
