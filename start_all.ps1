<#
================================================================================
 ShopConnector - Unified Mobility & Local Services Platform
 Master One-Click System Launcher (start_all.ps1)
 Native Windows 11 / PowerShell Execution - Zero Docker Dependencies
================================================================================
#>

param (
    [switch]$NoGui,
    [switch]$SkipAppLaunch
)

$Host.UI.RawUI.WindowTitle = "ShopConnector Master Control Center"
Clear-Host

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "    SHOPCONNECTOR - UNIFIED MOBILITY & LOCAL COMMERCE PLATFORM   " -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " Multi-Tenant Dispatch | 3-Shop Rate Cards | Live GPS | Intercity " -ForegroundColor White
Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray

$WorkspaceRoot = $PSScriptRoot
if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Get-Location
}

function Test-PortListening {
    param ([int]$Port)
    $active = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    return ($null -ne $active)
}

# 1. Check PostgreSQL (Port 5432)
Write-Host "[1/5] Checking PostgreSQL Database on Port 5432..." -NoNewline
if (Test-PortListening 5432) {
    Write-Host " [RUNNING / HEALTHY]" -ForegroundColor Green
} else {
    Write-Host " [NOT RUNNING]" -ForegroundColor Red
    Write-Host "       Attempting to start postgresql-x64-16 service..." -ForegroundColor Yellow
    Start-Service -Name "postgresql-x64-16" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (Test-PortListening 5432) {
        Write-Host "       PostgreSQL started successfully!" -ForegroundColor Green
    } else {
        Write-Host "       WARNING: PostgreSQL is not listening on 5432. Verify credentials in appsettings.json." -ForegroundColor Yellow
    }
}

# 2. Check Mosquitto MQTT Broker (Port 1883)
Write-Host "[2/5] Checking Mosquitto MQTT Broker on Port 1883..." -NoNewline
if (Test-PortListening 1883) {
    Write-Host " [RUNNING / HEALTHY]" -ForegroundColor Green
} else {
    Write-Host " [OPTIONAL / INACTIVE]" -ForegroundColor DarkGray
    $mosquittoExe = "C:\Program Files\mosquitto\mosquitto.exe"
    if (Test-Path $mosquittoExe) {
        Write-Host "       Launching local Mosquitto broker..." -ForegroundColor Cyan
        Start-Process $mosquittoExe -ArgumentList "-v" -WindowStyle Minimized
    }
}

# 3. Launch Python AI Microservice (Port 8000)
Write-Host "[3/5] Checking AI Microservice on Port 8000..." -NoNewline
if (Test-PortListening 8000) {
    Write-Host " [ALREADY RUNNING]" -ForegroundColor Green
} else {
    Write-Host " [STARTING]" -ForegroundColor Yellow
    $AiDir = Join-Path $WorkspaceRoot "ai-agent"
    $AiCmd = "cd '$AiDir'; python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle = 'ShopConnector - AI Microservice (Port 8000)'; $AiCmd"
    
    # Wait for AI service to respond
    $retry = 0
    while ($retry -lt 15) {
        Start-Sleep -Seconds 1
        if (Test-PortListening 8000) {
            Write-Host "       AI Microservice online at http://127.0.0.1:8000" -ForegroundColor Green
            break
        }
        $retry++
    }
}

# 4. Launch .NET 8 Web API (Port 5000)
Write-Host "[4/5] Checking ShopConnector Web API on Port 5000..." -NoNewline
if (Test-PortListening 5000) {
    Write-Host " [ALREADY RUNNING]" -ForegroundColor Green
} else {
    Write-Host " [STARTING]" -ForegroundColor Yellow
    $ApiProject = Join-Path $WorkspaceRoot "src\ShopConnector.Api\ShopConnector.Api.csproj"
    $ApiCmd = "cd '$WorkspaceRoot'; dotnet run --project '$ApiProject' --urls 'http://localhost:5000'"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle = 'ShopConnector - Core API (Port 5000)'; $ApiCmd"
    
    # Wait for API to respond
    $retry = 0
    while ($retry -lt 20) {
        Start-Sleep -Seconds 1
        if (Test-PortListening 5000) {
            Write-Host "       Core Web API online at http://localhost:5000" -ForegroundColor Green
            break
        }
        $retry++
    }
}

# 5. Summary & Interactive Menu
Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " All Core Backend Services are Online!" -ForegroundColor Green
Write-Host " API Docs / Swagger : http://localhost:5000/swagger" -ForegroundColor Cyan
Write-Host " AI Microservice    : http://127.0.0.1:8000/docs" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray

if ($SkipAppLaunch) {
    Write-Host "Launcher finished with -SkipAppLaunch flag." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Select an action for Flutter Client Application:" -ForegroundColor Yellow
Write-Host "  [1] Launch Flutter Desktop (Windows Native App)" -ForegroundColor White
Write-Host "  [2] Launch Flutter Web (Chrome)" -ForegroundColor White
Write-Host "  [3] Open Swagger UI in Browser" -ForegroundColor White
Write-Host "  [4] Open AI Agent Documentation" -ForegroundColor White
Write-Host "  [Q] Exit Launcher (Keep Services Running)" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice [1-4 or Q]"
$MobileDir = Join-Path $WorkspaceRoot "mobile"

switch ($choice) {
    "1" {
        Write-Host "Launching Flutter Windows Client..." -ForegroundColor Cyan
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$MobileDir'; flutter run -d windows"
    }
    "2" {
        Write-Host "Launching Flutter Web Client..." -ForegroundColor Cyan
        Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$MobileDir'; flutter run -d chrome"
    }
    "3" {
        Start-Process "http://localhost:5000/swagger"
    }
    "4" {
        Start-Process "http://127.0.0.1:8000/docs"
    }
    Default {
        Write-Host "Exiting Launcher. Background services are active in their separate consoles." -ForegroundColor Green
    }
}
