---
name: unified-mobility-platform
description: Comprehensive architecture, workflow, and engineering instructions for the Unified Mobility & Local Services Platform (ShopConnector). Use this skill whenever building, modifying, or testing multi-tenant identity, task dispatch, local Mosquitto MQTT GPS tracking, product catalog & orders, LiveKit calling, school transport, or AI orchestration on native Windows (No Docker).
---

# Unified Mobility & Local Services Platform (ShopConnector)

This skill provides the definitive engineering runbook, local architecture specifications, and implementation procedures for the **Unified Mobility & Local Services Platform**.

## 1. Core Operating Constraints & Guardrails

1. **NO DOCKER — Pure Native Windows Setup**:
   - PostgreSQL 18 on port `5432` (`shopconnector_core` and `shopconnector_telemetry`).
   - Eclipse Mosquitto MQTT broker on port `1883` (Local service, no 3rd party brokers).
   - Redis on port `6379` (Local Memurai or native Windows Redis for hot state & locks).
   - LiveKit Server on port `7880` (`livekit-server.exe --dev` native binary).
   - ASP.NET Core 8 Web API on port `5000` / `5001`.
   - React 18 Admin Dashboard on port `3000`.
   - Flutter Mobile App running natively on Emulator / Physical Device.
2. **Scalable Two-Database Architecture**:
   - `shopconnector_core`: Primary transactional data (users, businesses, orders, tasks, chat, invoices).
   - `shopconnector_telemetry`: High-volume location tracking time-series data. Partitioned monthly or moved to dedicated NVMe storage without touching core business tables.
3. **Smooth Cab / Driver Movement (App-to-App)**:
   - High-frequency GPS delta via local Mosquitto MQTT (2s-3s interval).
   - Hot state cached in Redis (`HSET latest_loc:{driverId}`).
   - Pushed via ASP.NET Core SignalR `TrackingHub`.
   - Flutter Client: Kalman Filter (removes jitter when stopped) + LatLng Tween interpolation (`Curves.linear`, 2000ms duration) + Shortest-angle bearing rotation (prevents 360 spin) + Route Snap-to-Road.
4. **Share-to-Track System**:
   - Users can share live tracking with other users via secure cryptographic tokens (`POST /api/v1/tracking/shares`).
   - If receiver has the Flutter App: Opens app directly, resolves token, connects to SignalR tracking group without exposing private customer/driver phone numbers.
   - If receiver opens in browser: Renders clean React/Web tracking map.
5. **Realtime Chat Engine**:
   - Built on native ASP.NET Core SignalR + Redis Backplane + PostgreSQL `messages` persistence.
   - Zero third-party vendor lock-in or recurring cloud costs.
6. **Race-Condition Safe Task Acceptance**:
   - Drivers receive wave broadcasts.
   - Acceptance uses atomic row locking (`SELECT ... FOR UPDATE` or Redis distributed lock).
   - First driver wins; other drivers immediately receive `TASK_ALREADY_TAKEN`.
   - Rejections are permanently stored in `task_driver_responses` to prevent annoying repeat broadcasts.
7. **Rate Limiting**:
   - ASP.NET Core 8 Rate Limiter middleware:
     - Auth: 5 requests / min (fixed window per IP).
     - API General: 120 requests / min (sliding window per user).
     - Dispatch Acceptance: 10 requests / min (anti-bot protection).
     - MQTT Location: 1 request / second token bucket.
8. **Configurable Dual OTP Verification (Pickup & Drop)**:
   - Configurable per task type/policy: `is_pickup_otp_required` and `is_drop_otp_required`.
   - **Pickup OTP**: Sender/Shop/Passenger shares OTP -> Driver submits via `POST /api/v1/tasks/{id}/verify-pickup-otp` -> State transitions from `AT_PICKUP` to `PICKED_UP`.
   - **Drop OTP**: Receiver/Customer shares OTP -> Driver submits via `POST /api/v1/tasks/{id}/verify-drop-otp` -> State transitions from `AT_DROP` to `COMPLETED`.
   - Supports SMS/Push fallback and resend endpoint `POST /api/v1/tasks/{id}/resend-otp?type=PICKUP|DROP`.
9. **Separate Python AI Agent (`ai-agent/`) with Pluggable Grok LLM**:
   - Independent FastAPI microservice running natively on Python 3.14 (port `8000`).
   - Pluggable provider architecture (`LLMProvider`) starting with Grok (xAI API), swappable to Gemini, Claude, or local Ollama via `LLM_PROVIDER=grok`.
   - Unified multi-persona assistant for Customer (voice order, live ride tracking), Shopkeeper (voice stock management, sales summary), and Driver (hands-free earnings and navigation).
   - Deterministic tool calling against ASP.NET Core API with strict human confirmation guardrails for financial actions.
10. **Multi-Shop Driver Privacy & Zero-Knowledge Isolation**:
   - Both Shop 1 and Shop 2 can independently add the same delivery boy by entering his mobile number.
   - **Zero-Knowledge Privacy**: Shop 1 queries strictly filter `WHERE business_id = @Shop1Id`. Shop 1 has zero visibility into whether the driver works for Shop 2 or what contract terms Shop 2 provides.
   - **Driver Experience**: Driver sees all linked shops in their app. Incoming task broadcast notifications explicitly display originating shop name, pickup address, and task earnings.
11. **Flexible Driver Compensation Engine**:
   - Per-shop customizable models: `FIXED_SALARY`, `PER_TASK`, `PER_KM`, `HYBRID_SALARY_TASK`, `HYBRID_KM_TASK`, `DYNAMIC_SURGE`.
   - Snapshotted permanently into `driver_earnings` upon task completion.
12. **Offline-First Telemetry & Batch Synchronization**:
   - Flutter Driver App buffers GPS points in local SQLite/Hive during weak/zero cellular connectivity.
   - Upon network reconnection, app flushes points in batches (50–100 points) to `POST /api/v1/tracking/batch-sync`.
   - Backend bulk-inserts into `shopconnector_telemetry.location_history` and updates Redis `latest_loc:{driverId}`.
   - Offline task state events (e.g. OTP verified offline) sync with top priority.
13. **Customer Proximity Discovery & Open Network Rider Toggle**:
   - Every shop stores exact `latitude`, `longitude`, and PostGIS geometry.
   - App fetches customer device GPS to calculate nearest shops via PostGIS `ST_DWithin` and stream nearby available riders within 3 km.
   - When added by a shopkeeper, a rider is a Dedicated Personal Rider (`is_network_enabled = FALSE`) by default.
   - Rider can enable 'Connect with Open Network' (`is_network_enabled = TRUE`) to receive direct customer broadcasts (cabs, shopping errands, P2P courier) alongside linked shop orders.
14. **Multi-Vehicle Garage & Single Active Vehicle Enforcement**:
   - A driver can register multiple vehicles (Bike, Auto, Cab Sedan, SUV) in their garage (`vehicles` table).
   - A driver can only be `ON_DUTY` on **EXACTLY ONE** vehicle at a time (`driver_profiles.active_vehicle_id`).
   - When going `ON_DUTY`, the driver selects their active vehicle, which dictates task eligibility (e.g., Bike for food/grocery/bike taxi; Cab for passenger bookings).
   - The assigned vehicle model and plate number are recorded in `task_assignments.vehicle_id` and displayed to the customer.
15. **Driver Configurable Operating Radii (Pickup vs. Delivery)**:
   - Drivers independently configure two operating thresholds in `driver_profiles`:
     - `max_pickup_radius_km`: Distance from current location to pickup point (e.g., within 1 km).
     - `max_delivery_radius_km`: Total delivery distance from pickup to drop (e.g., within 10 km).
   - The dispatch engine strictly verifies both spatial conditions before broadcasting a task to a driver.
16. **Granular Driver Operational Status Lifecycle**:
   - Status transitions strictly across 6 deterministic states:
     - `OFF_DUTY`: Offline / resting.
     - `FREE`: Online, idle, and eligible to receive nearby broadcasts.
     - `EN_ROUTE_PICKUP`: Task accepted, on-duty driving to pickup location.
     - `AT_PICKUP`: Arrived at pickup, waiting for goods/passenger & Pickup OTP verification.
     - `PICKED_UP`: Pickup OTP verified, traveling to customer drop.
     - `AT_DROP`: Arrived at destination, awaiting Drop OTP verification.
   - Upon Drop OTP verification, driver immediately returns to `FREE`.
17. **Comprehensive Audit & Communications Logging**:
   - Every state transition, action, and permission check is logged to `audit_logs` (actor_id, role, entity_type, action, ip_address, old/new states).
   - Every outbound communication is logged to `communication_logs` (SMS, WhatsApp, Email, Push with recipient, provider message ID, and delivery status).
18. **Driver Inter-City Route Banners via AI Query Box**:
   - Drivers can schedule one-way or return inter-city trips (e.g. *Jaipur to Delhi tomorrow at 11 AM for ₹1500*) by typing or speaking in the app AI box.
   - The Python AI Agent (`ai-agent/`) parses the prompt and calls `create_driver_trip_banner()`.
   - Saves into `driver_trip_offers` and triggers automated in-app banners, push alerts, and WhatsApp messages to customers traveling that route.
19. **Digital Khata Ledger & Flexible Doorstep Payment (Udhar Management)**:
   - Doorstep payment collection supports 3 flexible modes: **Cash**, **Dynamic UPI QR Code**, and **Dues / Khata (Udhar)**.
   - Dues mode is **strictly gated by the shopkeeper**:
     - Global shop-level toggle `is_dues_enabled`.
     - Per-customer whitelist `business_customer_khata.is_dues_enabled = TRUE` and individual `credit_limit` (e.g. ₹2,000 or ₹5,000).
     - Delivery boy app only shows the `[Add to Khata]` button if the shopkeeper has authorized credit for that specific customer and the order total is within the remaining credit limit.
     - Transactions are permanently logged to `khata_transactions` with automated SMS/WhatsApp debt receipts sent to the customer.
20. **Apartment Street Vendor Voice AI, Local Meetups & Community Classifieds**:
   - **Voice Grocery AI (Hindi/Hinglish/English)**: Parses spoken/typed grocery requests (e.g. *"5kg aaloo, 2 kg pyaz, 1 kg tomato"*) into structured line items, calculates total prices, and routes them to apartment vendors/kirana stores.
   - **Hyperlocal Social Meetups & Casual Dating**: Safe casual hangouts and coffee dates ("Free for coffee tomorrow 5 PM") with public venue verification (cafes/malls only), phone number masking, LiveKit calling, mutual match requests, and emergency SOS panic triggers.
   - **Community Classifieds & Skill Bounties**: Hyperlocal hiring bounties (e.g. *"Need teacher for my kids 5 year budget ₹600 monthly"*, maids, cooks, babysitters) with spatial radius matching and tutor proposal reviews.
21. **3 Customer Request Modes, AI Intent Decision & GitHub Monorepo Deployment**:
   - **3 Request Modes**:
     - *Mode A (Single Shop)*: Direct order/quote to 1 chosen shopkeeper.
     - *Mode B (Selective Multi-Shop)*: Select 2 or 3 shops ("tino se rate mango") -> shops submit itemized quotes -> app renders side-by-side comparative rates card.
     - *Mode C (Open Network)*: Broadcasts RFQ to all neighborhood vendors within 3-5 km.
   - **AI Intent Decision Engine**: Grok LLM automatically detects whether user wants price discovery (`RATE_INQUIRY`) or immediate checkout (`DIRECT_ORDER`).
   - **GitHub Remote Repository**: All platform microservices, database schemas, and mobile apps are structured for upload and CI/CD at `https://github.com/prem78niit/shop_connector`.
22. **Daily Recurring Subscriptions, Vacation Mode & Automated Month-End Khata Sync**:
   - **Morning Auto-Dispatch (06:00 AM – 07:30 AM)**: Native cron worker triggers at 04:30 AM, evaluates active `subscriptions`, skips days falling in `subscription_pauses`, and routes cluster morning delivery tasks.
   - **1-Tap & Voice Vacation Mode**: Customers pause deliveries with 1 tap or voice (*"Kal se 5 din tak milk delivery pause"*), recorded in `subscription_pauses`. Skipped days are billed at ₹0.00.
   - **Month-End Automated Khata Sync**: Runs on the 1st of every month, totals delivered items (`subscription_daily_logs`), subtracts vacation days, auto-generates consolidated debt in `khata_transactions` (`DUES_ADDED`), and pushes itemized WhatsApp calendar statements.
23. **Pluggable Distance Engine (Haversine Default) & Operational Edge-Case Defenses**:
   - **Haversine Distance Engine (Phase 1 Default)**: High-speed in-memory spherical distance calculation multiplied by empirical urban road factor ($\times 1.30$) with 25 km/h city speed ($+3$ min buffer). Completely eliminates external Google Maps API bills and 10GB OSRM map downloads during local development. Pluggable `IDistanceMatrixService` allows switching to OSRM/Google via `appsettings.json` later.
   - **Operational Defenses**:
     - *Dynamic Vegetable Price Handshake*: Customer confirms shopkeeper-packed rates before driver dispatch to prevent doorstep rejections.
     - *Khata Credit Risk Gating*: Shopkeeper-authorized credit limits linked to apartment resident profiles.
     - *Meetup Safety Shield*: Verified public cafes/malls only, phone number masking, LiveKit WebRTC calling, and 1-tap SOS alerts.
     - *Modular 3-Tab UI*: Partitions app into Mobility, Daily Essentials & Khata, and Society & Meetups.
24. **Simplified Mobile + 4-Digit PIN Auth & Driver Single-Device Order Enforcement**:
   - **PIN Auth (Phase 1)**: Login via Mobile Number + 4-digit PIN (default `1234`). Eliminates external SMS gateway costs and OTP delays during development. Seamlessly toggles to SMS OTP in production.
   - **Device Session Audit**: `user_device_sessions` table permanently logs who logged in, when, from which device ID, device name, and IP address.
   - **Driver Single-Device Enforcement**: A driver **CANNOT** run the same order from two concurrent devices!
     - If driver has an active task in progress (`EN_ROUTE_PICKUP` to `AT_DROP`), logging in on Device 2 is strictly **BLOCKED** (`409 Conflict`).
     - If driver is idle, logging in on Device 2 terminates Device 1 session (SignalR `ForceLogout` event + Redis JWT blacklist).
     - Task execution is bound to `task_assignments.device_id`; telemetry pings from unauthorized devices are rejected with `403 Forbidden`.

---

## 2. Standard Development Workflows

### Workflow 1: Local Services Initialization (Native Windows)
To start the local development stack:
1. Verify PostgreSQL 18 is running: `Get-Service -Name postgresql-x64-18`
2. Verify Mosquitto MQTT is running: `Get-Service -Name mosquitto`
3. Launch Redis (Memurai / Redis Windows): `redis-server.exe --port 6379`
4. Launch LiveKit native server: `livekit-server.exe --dev --bind 127.0.0.1`
5. Run Backend API: `dotnet run --project src/ShopConnector.Api`
6. Run React Dashboard: `npm run dev --prefix dashboard`
7. Run Flutter Mobile App: `flutter run`

---

### Workflow 2: Implementing Domain Features & Migrations
1. **Schema Check**:
   - Core transactional tables go to `shopconnector_core`.
   - Telemetry tables go to `shopconnector_telemetry`.
   - Reference: [WORKFLOW.md](../../WORKFLOW.md#2-complete-database-schemas-ddl-sql).
2. **Entity Framework Core Migrations**:
   - Keep migrations organized per database context (`CoreDbContext` and `TelemetryDbContext`).
3. **Multi-Tenant Scoping**:
   - Every query MUST filter by `BusinessId` or `TenantId` derived from the validated JWT token, never from user payload.
4. **Idempotency**:
   - Accept `Idempotency-Key` header on all order creation, payment, and task assignment requests.

---

### Workflow 3: Smooth Movement Pipeline Execution
1. **Driver Location Publish**:
   - Topic: `tracking/v1/{tenantId}/driver/{driverId}/location`
   - JSON: `{"lat": 25.594, "lng": 85.137, "bearing": 90.0, "speed": 12.5, "ts": 1774450000}`
2. **Worker Processing**:
   - Updates Redis key `latest_loc:{driverId}`.
   - Pushes delta to SignalR group `Tracking_Task_{taskId}`.
   - Asynchronously batches sampled points to `shopconnector_telemetry.location_history`.
3. **Flutter Client Animation**:
   - Apply `SmoothMarkerAnimator` with LatLng lerp and shortest delta angle calculation.
   - Reference: [WORKFLOW.md](../../WORKFLOW.md#3-high-performance-realtime-telemetry--smooth-movement-architecture).

---

### Workflow 4: Share-to-Track Link Resolution
1. Caller issues `POST /api/v1/tracking/shares` with `{ taskId: "..." }`.
2. Backend generates cryptographically random token with expiry.
3. Recipient opens URL `https://app.shopconnector.local/track/{token}`.
4. Flutter App catches deep link, resolves token via `GET /api/v1/tracking/shares/{token}`, joins SignalR live room, and streams the smooth moving cab marker without exposing PII.

---

## 3. Definition of Done Checklist

Every PR or feature change must satisfy:
- [ ] No Docker dependencies introduced (runs cleanly on native Windows environment).
- [ ] Core DB (`shopconnector_core`) vs Telemetry DB (`shopconnector_telemetry`) separation maintained.
- [ ] Rate limiting policy applied to new public endpoints.
- [ ] Concurrency and transactional locking tested for state transitions (e.g. task acceptance).
- [ ] SignalR real-time event dispatched for live UI updates.
- [ ] Flutter UI handles smooth animations, loading states, and offline retry queues.
- [ ] Privacy rules enforced: Driver/Customer phone numbers and exact private locations are masked on shared views.
