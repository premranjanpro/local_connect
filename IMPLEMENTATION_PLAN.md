# Master Development Plan — Unified Mobility & Local Services Platform (ShopConnector)

## 1. Executive Summary & Core Engineering Guardrails

1. **100% Native Windows Setup (NO DOCKER)**:
   - PostgreSQL 18 on port `5432` (`shopconnector_core` & `shopconnector_telemetry`).
   - Eclipse Mosquitto MQTT broker on port `1883` (Windows service).
   - Redis on port `6379` (Memurai / native Redis for hot latest coordinates & distributed locks).
   - LiveKit Server on port `7880` (`livekit-server.exe --dev --bind 127.0.0.1`).
   - ASP.NET Core 8 Web API on port `5000` / `5001`.
   - Standalone Python 3.14 AI Agent (`ai-agent/`) on port `8000`.
   - Flutter Mobile App (Emulator / physical device via local Wi-Fi / tunnel).
   - React 18 / Vite Admin Dashboard on port `3000`.
2. **Simplified Mobile Number + 4-Digit PIN Authentication (Phase 1)**:
   - Login: `phone_number` + 4-digit PIN (default `1234` for rapid development/testing).
   - Eliminates external SMS OTP gateway delays, costs, and DLT registration hurdles.
   - Clean migration path: Can toggle to SMS OTP for new user onboarding in production via config.
3. **Device Audit & Driver Single-Device Concurrency Enforcement**:
   - Every login session logged in `user_device_sessions` table (`who, when, what device, platform, ip_address`).
   - **Strict Concurrency Rule**: A driver **CANNOT** log into two devices to run the same order!
     - If an active task is running (`status` in `[EN_ROUTE_PICKUP, AT_PICKUP, PICKED_UP, AT_DROP]`), logging in from a second device is **BLOCKED** (`409 Conflict`).
     - If driver is idle, logging into Device 2 immediately revokes Device 1 (`ForceLogout` via SignalR + JWT blacklisted in Redis).
     - Active task is bound to `task_assignments.device_id`. GPS pings from any other device are rejected with `403 Forbidden`.
4. **Pluggable Distance & Duration Engine (Haversine Default)**:
   - In-memory Haversine distance with empirical urban road factor ($\times 1.30$) and 25 km/h city speed calculation ($+3$ min buffer).
   - Eliminates Google Maps API bills and 10GB OSRM map PBF downloads during development.
   - Swappable to OSRM or Google Maps via `appsettings.json` in production.
5. **Target Remote GitHub Repository**:
   - `https://github.com/prem78niit/shop_connector`

---

## 2. Phased Implementation Roadmap

```
+----------------------------------------------------------------------------------------------------+
|                                MASTER 7-PHASE DEVELOPMENT ROADMAP                                  |
|                                                                                                    |
|  [PHASE 0: Repo & Environment Setup]                                                               |
|  - Git init, remote setup (https://github.com/prem78niit/shop_connector), Windows services check   |
|                               |                                                                    |
|                               v                                                                    |
|  [PHASE 1: Backend Scaffolding & PIN Auth (.NET 8 + Postgres 18)]                                  |
|  - Clean Architecture (.sln), EF Core DbContexts, PIN Auth (1234), Device Audit & Concurrency      |
|                               |                                                                    |
|                               v                                                                    |
|  [PHASE 2: Business Catalog & Multi-Shop Driver Privacy (.NET 8)]                                  |
|  - Shop profiles, product catalog, zero-knowledge multi-shop driver contracts & garage vehicles    |
|                               |                                                                    |
|                               v                                                                    |
|  [PHASE 3: Orders, Tasks, Dual OTP, Haversine Routing & Digital Khata]                             |
|  - Task state machine, atomic row locking, Dual OTP, Haversine distance, Khata credit ledger        |
|                               |                                                                    |
|                               v                                                                    |
|  [PHASE 4: Realtime Telemetry, Mosquitto MQTT & Smooth Tracking]                                   |
|  - Mosquitto MQTT ingestion worker, Redis hot caching, SignalR live delta, LiveKit calling tokens  |
|                               |                                                                    |
|                               v                                                                    |
|  [PHASE 5: Standalone Python AI Agent Microservice (FastAPI + Grok)]                               |
|  - Grok LLM integration, voice grocery NLP, 3 request modes classifier (Rate vs Direct Order)      |
|                               |                                                                    |
|                               v                                                                    |
|  [PHASE 6: Unified Multi-Role Flutter Mobile App (Dart/Flutter)]                                   |
|  - Customer, Driver, Shopkeeper views, Kalman filter smooth cab marker, 3-tab UI, Khata collection  |
|                               |                                                                    |
|                               v                                                                    |
|  [PHASE 7: React Admin Dashboard & End-to-End Hardening]                                           |
|  - React 18 / Vite shopkeeper portal, concurrency stress tests, final push to GitHub               |
+----------------------------------------------------------------------------------------------------+
```

---

### Phase 0: Repository & Local Environment Verification (Day 1)
- [ ] Initialize local Git monorepo:
  ```powershell
  git init
  git remote add origin https://github.com/prem78niit/shop_connector.git
  git branch -M main
  ```
- [ ] Create comprehensive `.gitignore` for .NET 8, Flutter, Python, Node, and Windows native files.
- [ ] Verify local Windows services:
  - PostgreSQL 18: `Get-Service -Name postgresql-x64-18`
  - Mosquitto MQTT: `Get-Service -Name mosquitto`
  - Redis (Memurai / Redis Windows): `redis-cli ping` -> `PONG`
  - LiveKit Server: `livekit-server.exe --dev`
- [ ] Commit initial architecture documents and push to GitHub.

---

### Phase 1: Backend Scaffolding & PIN Authentication Engine (Days 2–4)
- [ ] Create .NET Core 8 Clean Architecture solution:
  - `src/ShopConnector.Api` (Controllers, SignalR Hubs, Middleware)
  - `src/ShopConnector.Core` (Entities, Interfaces, Enums, DTOs)
  - `src/ShopConnector.Infrastructure` (EF Core Postgres, Redis, Mosquitto, SignalR)
- [ ] Configure two EF Core DbContexts:
  - `CoreDbContext` -> `shopconnector_core` (23 relational tables)
  - `TelemetryDbContext` -> `shopconnector_telemetry` (monthly partitioned `location_history`)
- [ ] Implement Simplified Authentication:
  - `POST /api/v1/auth/login-pin` (Phone number + 4-digit PIN, default `1234`).
  - Password hashing with BCrypt / Argon2.
  - JWT token generation (15 min access token + 30-day refresh token).
- [ ] Implement Device Audit & Concurrency Enforcement:
  - `user_device_sessions` table insertion upon login (`device_id`, `device_name`, `platform`, `ip_address`).
  - Driver Single-Device Concurrency Middleware:
    - If driver has an active task in progress -> Block login on Device 2 with `409 Conflict`.
    - If driver is idle -> Invalidate Device 1, push SignalR `ForceLogout`, blacklist JWT in Redis.
- [ ] Implement Pluggable Distance Service:
  - Interface `IDistanceMatrixService`.
  - Default `HaversineDistanceService` ($\times 1.30$ road factor, 25 km/h speed, $+3$ min buffer).
  - Config flag in `appsettings.json`.

---

### Phase 2: Business Catalog & Multi-Shop Driver Privacy (Days 5–8)
- [ ] Implement Shopkeeper APIs:
  - Create/manage shop profiles (`businesses` table).
  - Product catalog & SKU management (`products`, `business_products`).
  - Live stock availability toggles (`is_available`).
- [ ] Implement Multi-Shop Driver Privacy Isolation:
  - Shop adds driver by mobile number (`POST /api/v1/businesses/{id}/drivers`).
  - Contract models (`FIXED_SALARY`, `PER_TASK`, `PER_KM`, `HYBRID`).
  - Zero-Knowledge queries: Shop 1 queries strictly filter `WHERE business_id = @Shop1Id`. Zero visibility of driver working for Shop 2.
- [ ] Driver Vehicle Garage:
  - Register multiple vehicles (Bike, Auto, Cab Sedan) in `vehicles` table.
  - Single active vehicle enforcement: Driver selects exactly one active vehicle when going `ON_DUTY`.
- [ ] Driver Operating Preferences:
  - Configurable `max_pickup_radius_km` (e.g. 1 km) and `max_delivery_radius_km` (e.g. 10 km).
  - "Connect with Open Network" toggle (`is_network_enabled = TRUE/FALSE`).

---

### Phase 3: Orders, Tasks, Dual OTP & Digital Khata Ledger (Days 9–12)
- [ ] Universal Task Engine:
  - State machine: `REQUESTED` -> `BROADCASTING` -> `ASSIGNED` -> `EN_ROUTE_PICKUP` -> `AT_PICKUP` -> `PICKED_UP` -> `AT_DROP` -> `COMPLETED`.
  - Atomic broadcast acceptance using PostgreSQL `SELECT ... FOR UPDATE` (Anti-race condition).
  - Device binding: `task_assignments.device_id`.
- [ ] Dual OTP Security Matrix:
  - Pickup OTP verification: `POST /api/v1/tasks/{id}/verify-pickup-otp` (`AT_PICKUP` -> `PICKED_UP`).
  - Drop OTP verification: `POST /api/v1/tasks/{id}/verify-drop-otp` (`AT_DROP` -> `COMPLETED`).
- [ ] Digital Khata / Udhar Ledger Engine:
  - Global shop toggle `is_khata_enabled`.
  - Per-customer credit gating: `business_customer_khata` (`is_dues_enabled`, `credit_limit`, `current_due_balance`).
  - Doorstep payment collection endpoint: Cash vs Dynamic UPI QR vs Khata.
  - Automatic balance updates and logging in `khata_transactions`.
- [ ] Multi-Shop RFQs & Quotations:
  - 3 Customer Request Modes: Single Shop, 3 Selected Shops, Open Network Broadcast.
  - `customer_rfqs` and `rfq_business_quotes` tables.
- [ ] Daily Recurring Subscriptions:
  - Auto-dispatch schedule (06:00 AM – 07:30 AM).
  - 1-Tap Vacation Mode (`subscription_pauses`).
  - Month-end automated billing sync to Khata.

---

### Phase 4: Realtime Telemetry, Mosquitto MQTT & SignalR (Days 13–15)
- [ ] Mosquitto MQTT Telemetry Ingestion Worker:
  - Background worker subscribes to `tracking/v1/{tenantId}/driver/{driverId}/location`.
  - Caches latest coordinate in Redis (`HSET latest_loc:{driverId}`).
  - Pushes realtime delta via SignalR `TrackingHub`.
  - Asynchronously batches historical points into `shopconnector_telemetry.location_history`.
- [ ] Share-to-Track System:
  - Cryptographic token generation (`POST /api/v1/tracking/shares`).
  - Deep-link resolution for in-app and web tracking without PII exposure.
- [ ] Realtime Chat & LiveKit Calling:
  - SignalR `ChatHub` with Redis backplane.
  - LiveKit WebRTC room token generation (`POST /api/v1/calls/token`).

---

### Phase 5: Standalone Python AI Agent Microservice (`ai-agent/`) (Days 16–18)
- [ ] Scaffold FastAPI project in `ai-agent/` (Python 3.14, Port 8000).
- [ ] Implement Pluggable LLM Provider (`GrokProvider` using `xai-api`, swappable to Gemini/Claude).
- [ ] Implement Deterministic Tool Calling Engine:
  - `parse_grocery_voice_order`: Parses spoken Hindi/Hinglish vegetable lists into structured JSON.
  - `process_customer_grocery_intent`: Classifies query into `RATE_INQUIRY` (request quotes) vs `DIRECT_ORDER` (immediate cart).
  - `pause_subscription`: 1-tap/voice Vacation Mode toggle.
  - `record_khata_transaction`: Records store credit or repayment.
  - `create_driver_trip_banner`: Inter-city scheduled ride banners (e.g. Jaipur to Delhi).
  - `post_social_meetup`: Casual hangout/coffee date with public venue geofencing.
  - `post_community_classified`: Kids tutor / maid / cook hiring bounties.

---

### Phase 6: Unified Multi-Role Flutter Mobile App (`mobile/`) (Days 19–24)
- [ ] Scaffold Flutter app with `flutter_bloc` / `riverpod`.
- [ ] Role Switcher: Customer, Driver, Shopkeeper, School Parent.
- [ ] Driver Operational View:
  - "Go Online" toggle with active vehicle selector modal.
  - Radar wave broadcast card with countdown timer & slide-to-accept.
  - In-app navigation with Kalman filter & smooth marker bearing rotation.
  - Doorstep payment collection screen: [Cash Received] [Show UPI QR] [Add to Khata].
  - Single-device enforcement: Receives `ForceLogout` SignalR event if logged in elsewhere.
- [ ] Customer Operational View:
  - Modular 3-Tab UI (Tab 1: Mobility & Cabs, Tab 2: Daily Essentials & Khata, Tab 3: Society & Community).
  - Voice order mic button (Hindi/Hinglish speech-to-text).
  - Side-by-side multi-shop quotation comparison matrix.
  - Realtime smooth cab/delivery tracking card with share-to-WhatsApp button.
- [ ] Shopkeeper Operational View:
  - Kanban order board (New -> Preparing -> Out for Delivery -> Done).
  - Dynamic rate packing screen for vegetable orders.
  - Customer Khata ledger manager (whitelist toggle + credit limits).

---

### Phase 7: React 18 Admin Dashboard & System Hardening (Days 25–28)
- [ ] Scaffold React 18 / Vite Admin Dashboard in `dashboard/` (Port 3000).
- [ ] Live spatial map of online drivers and active orders.
- [ ] Comprehensive Audit Trail viewer (`audit_logs`) and Communication delivery tracker (`communication_logs`).
- [ ] Concurrency & Load Testing:
  - Test simultaneous drivers accepting the same task broadcast (Zero duplicate assignments).
  - Test driver logging in from two devices with active order (Strictly blocked).
  - Test offline GPS buffering and batch sync under network drops.
- [ ] Push all completed code and migrations to GitHub:
  ```powershell
  git add .
  git commit -m "feat: complete end-to-end production implementation of shop_connector"
  git push -u origin main
  ```

---

## 3. Definition of Done Checklist

Before any phase is marked complete:
- [ ] 100% Native Windows execution — ZERO Docker dependencies.
- [ ] Both databases (`shopconnector_core` & `shopconnector_telemetry`) operate smoothly.
- [ ] Phone + 4-digit PIN (`1234`) login works reliably with device session logging.
- [ ] Driver cannot run the same order from two concurrent devices.
- [ ] Haversine distance and duration engine executes in $< 0.05\text{ ms}$.
- [ ] Rate limits applied to public endpoints (`429 Too Many Requests`).
- [ ] Code formatted and pushed to `https://github.com/prem78niit/shop_connector`.
