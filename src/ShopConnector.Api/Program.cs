using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using ShopConnector.Core.Interfaces;
using ShopConnector.Infrastructure.Data;
using ShopConnector.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);

// 1. Database Connections
var coreDbConn = builder.Configuration.GetConnectionString("CoreDb");
var telemetryDbConn = builder.Configuration.GetConnectionString("TelemetryDb");

builder.Services.AddDbContext<CoreDbContext>(options =>
{
    options.UseNpgsql(coreDbConn, npgsqlOptions =>
    {
        npgsqlOptions.UseNetTopologySuite();
        npgsqlOptions.EnableRetryOnFailure(5, TimeSpan.FromSeconds(5), null);
    });
});

builder.Services.AddDbContext<TelemetryDbContext>(options =>
{
    options.UseNpgsql(telemetryDbConn, npgsqlOptions =>
    {
        npgsqlOptions.UseNetTopologySuite();
        npgsqlOptions.EnableRetryOnFailure(5, TimeSpan.FromSeconds(5), null);
    });
});

// 2. Core & Domain Services
builder.Services.AddScoped<IDistanceMatrixService, HaversineDistanceService>();
builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddScoped<IAuditService, AuditService>();
builder.Services.AddScoped<IFcmNotificationService, FcmNotificationService>();
builder.Services.AddScoped<ILiveKitService, LiveKitService>();

// 2.1 MQTT Telemetry Ingestion & Publishing
builder.Services.Configure<ShopConnector.Api.Services.Mqtt.MqttOptions>(builder.Configuration.GetSection("Mqtt"));
builder.Services.AddSingleton<ShopConnector.Api.Services.Mqtt.MqttLocationIngestionService>();
builder.Services.AddSingleton<IMqttPublisher>(sp => sp.GetRequiredService<ShopConnector.Api.Services.Mqtt.MqttLocationIngestionService>());
builder.Services.AddHostedService(sp => sp.GetRequiredService<ShopConnector.Api.Services.Mqtt.MqttLocationIngestionService>());

// 2.2 Morning Subscription Auto-Dispatch Worker (Daily 04:30 UTC = 10:00 AM IST)
builder.Services.AddHostedService<ShopConnector.Api.Services.Workers.SubscriptionDispatchWorker>();

// 2.3 Webhook Delivery Service (fires HTTP POST to registered endpoints)
builder.Services.AddHttpClient("webhook", c =>
{
    c.Timeout = TimeSpan.FromSeconds(8);
    c.DefaultRequestHeaders.Add("User-Agent", "ShopConnector-Webhook/1.0");
});
builder.Services.AddScoped<ShopConnector.Api.Services.IWebhookService, ShopConnector.Api.Services.WebhookService>();

// 2.4 Notification Queue & Retry Worker (30s polling, exponential back-off)
// Guarantees delivery even when driver is offline — preserves original event timestamps
builder.Services.AddScoped<ShopConnector.Api.Services.INotificationEnqueueService,
    ShopConnector.Api.Services.NotificationEnqueueService>();
builder.Services.AddHostedService<ShopConnector.Api.Services.Workers.NotificationRetryWorker>();

// 3. JWT Authentication Setup
var jwtSecret = builder.Configuration["Jwt:SecretKey"] ?? "ShopConnectorUltraSecureSecretKey2026!LongEnoughForSha256Signature";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "ShopConnectorApi";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "ShopConnectorApp";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
        ValidateIssuer = true,
        ValidIssuer = jwtIssuer,
        ValidateAudience = true,
        ValidAudience = jwtAudience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromMinutes(5)
    };
});

builder.Services.AddAuthorization();

// 4. Controllers with JSON String Enum Converters
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
        options.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
        options.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles;
    });

// 5. Swagger with Bearer Auth
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "ShopConnector Unified Mobility & Local Services API",
        Version = "v1",
        Description = "Enterprise backend for multi-tenant mobility, delivery dispatch, digital khata, and hyper-local matchmaking."
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Format: 'Bearer {token}'",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// 6. CORS for Local Web and Flutter App testing
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// 7. Real-time SignalR Hubs
builder.Services.AddSignalR();

var app = builder.Build();

// Auto-run EF Migrations and ensure DB schema exists
using (var scope = app.Services.CreateScope())
{
    var coreDb = scope.ServiceProvider.GetRequiredService<CoreDbContext>();
    var telemetryDb = scope.ServiceProvider.GetRequiredService<TelemetryDbContext>();
    coreDb.Database.EnsureCreated();
    telemetryDb.Database.EnsureCreated();
}

app.UseCors("AllowAll");

if (app.Environment.IsDevelopment() || true) // Enable Swagger for development and testing
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "ShopConnector API v1");
        c.RoutePrefix = "swagger";
    });
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<ShopConnector.Api.Hubs.TaskHub>("/hubs/tasks");
app.MapHub<ShopConnector.Api.Hubs.TelemetryHub>("/hubs/telemetry");
app.MapHub<ShopConnector.Api.Hubs.ChatHub>("/hubs/chat");

app.Run();

