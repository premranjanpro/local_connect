# Unified Mobility & Local Services Platform (ShopConnector)
## Master Production Architecture & Complete Implementation Workflow

---

## 1. Local Infrastructure Blueprint (100% Native — NO DOCKER)

All system services run natively on the Windows host machine for maximum speed, native debugging, zero virtualization overhead, and direct file access.

```
+-----------------------------------------------------------------------------------+
|                            LOCAL WINDOWS HOST MACHINE                             |
|                                                                                   |
|  +--------------------+   +-----------------------+   +------------------------+  |
|  |   PostgreSQL 18    |   |   Mosquitto MQTT      |   |   Redis (Port 6379)    |  |
|  |   (Port 5432)      |   |   (Port 1883)         |   |   Memurai / Native     |  |
|  |   - Core DB        |   |   - High-freq GPS     |   |   - Hot latest locs    |  |
|  |   - Telemetry DB   |   |   - Device telemetry  |   |   - Dispatch locks     |  |
|  +--------------------+   +-----------------------+   +------------------------+  |
|                                                                                   |
|  +--------------------+   +-----------------------+   +------------------------+  |
|  | LiveKit Server     |   | ASP.NET Core 8 API    |   | Python AI Agent        |  |
|  | (Port 7880 / Native)   | (Port 5000 / 5001)    |   | (Port 8000 / FastAPI)  |  |
|  | - Audio/Video Calls|   | - SignalR / WebSockets|   | - Grok / Multi-Role    |  |
|  +--------------------+   +-----------------------+   +------------------------+  |
|                                                                                   |
|  +--------------------+   +-----------------------+   +------------------------+  |
|  | Background Workers |   | Flutter Mobile App    |   | React 18 Web Dashboard |  |
|  | Tracking, Dispatch |   | Single App: All Roles |   | Admin & Shop Analytics |  |
|  +--------------------+   +-----------------------+   +------------------------+  |
+-----------------------------------------------------------------------------------+
```

### Local Services Configuration Matrix

| Component | Host Port | Status & Local Binary Path | Configuration & Run Command |
| :--- | :--- | :--- | :--- |
| **PostgreSQL 18** | `5432` | Installed as Windows Service (`postgresql-x64-18`) | Hosts 2 separate databases: `shopconnector_core` and `shopconnector_telemetry` |
| **Mosquitto MQTT** | `1883` | Installed as Windows Service (`mosquitto`) | Local config: `C:\Program Files\mosquitto\mosquitto.conf` with local ACL authentication |
| **Redis Cache** | `6379` | Native Memurai / Redis Windows | `memurai.exe` or `redis-server.exe --port 6379 --maxmemory 1gb` |
| **LiveKit Server** | `7880` | Native Windows executable | Download `livekit-server.exe` -> `.\livekit-server.exe --dev --bind 127.0.0.1` |
| **ASP.NET Core API**| `5000/5001`| `C:\Program Files\dotnet\dotnet.exe` | `dotnet run --project src/ShopConnector.Api` |
| **Python AI Agent** | `8000` | Native Python 3.14 (`python.exe`) | `cd ai-agent && uvicorn app.main:app --port 8000 --reload` |
| **React Dashboard** | `3000` | `C:\Program Files\nodejs\node.exe` | `cd dashboard && npm run dev` |
| **Flutter App** | Emulator/USB | `C:\Windows\system32\flutter.bat` | `cd mobile && flutter run` |

---

## 2. Complete Database Schemas (DDL SQL)

To achieve **extreme horizontal scalability**, telemetry and location tracking data are separated from business transactions:
1. **Primary Core Database (`shopconnector_core`)**: Handles identity, shops, products, orders, tasks, chat, calls, invoices, and ratings.
2. **Dedicated Telemetry Database (`shopconnector_telemetry`)**: Dedicated time-series database for raw and sampled location history. It can be moved to a separate NVMe disk or TimescaleDB cluster without touching the core relational database.

### 2.1 Primary Core Database (`shopconnector_core`) DDL

```sql
CREATE DATABASE shopconnector_core;
\c shopconnector_core;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 1. USERS & IDENTITY
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    pin_hash VARCHAR(255) NOT NULL DEFAULT '$2a$11$default_pin_hash_1234', -- 4-digit PIN (default 1234 for instant testing)
    email VARCHAR(255) UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    avatar_url TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, SUSPENDED, PENDING_OTP
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. BUSINESSES & SHOPS
CREATE TABLE businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(150) NOT NULL,
    business_type VARCHAR(50) NOT NULL, -- GROCERY, PHARMACY, RESTAURANT, LAUNDRY, CAB_SERVICE, SERVICE_PRO
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    phone VARCHAR(20),
    email VARCHAR(255),
    address_text TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geom GEOMETRY(Point, 4326),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_khata_enabled BOOLEAN NOT NULL DEFAULT FALSE, -- Shopkeeper master toggle for Dues / Udhar Khata
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_businesses_geom ON businesses USING GIST (geom);

-- 3. BUSINESS MEMBERSHIPS & ROLES (Multi-tenant RBAC)
CREATE TABLE business_memberships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL, -- OWNER, MANAGER, BILLING, DISPATCHER, DRIVER
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_id, user_id, role)
);

-- 4. VEHICLES & DRIVER GARAGE (Multi-Vehicle Support)
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_type VARCHAR(30) NOT NULL, -- BIKE, AUTO, CAB_SEDAN, CAB_SUV, TRUCK
    brand_model VARCHAR(100) NOT NULL, -- e.g. "Hero Splendor Plus", "Maruti Dzire"
    plate_number VARCHAR(30) UNIQUE NOT NULL, -- e.g. "BR-01-AB-1234"
    color VARCHAR(30),
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- Active in driver's garage
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_vehicles_driver ON vehicles(driver_user_id);

-- DRIVER PROFILES (Enforces Single Active Vehicle & Configurable Operating Radii)
CREATE TABLE driver_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(50) NOT NULL,
    duty_status VARCHAR(30) NOT NULL DEFAULT 'OFF_DUTY', -- OFF_DUTY, FREE (Available), EN_ROUTE_PICKUP, AT_PICKUP, PICKED_UP, AT_DROP
    active_vehicle_id UUID REFERENCES vehicles(id), -- Only ONE vehicle can be active when ON_DUTY!
    is_network_enabled BOOLEAN NOT NULL DEFAULT FALSE, -- Connect with Open Network
    max_pickup_radius_km NUMERIC(5,2) NOT NULL DEFAULT 2.00, -- Maximum distance from current location to pickup point (e.g. 1 km)
    max_delivery_radius_km NUMERIC(5,2) NOT NULL DEFAULT 10.00, -- Maximum trip distance from pickup to drop point (e.g. 10 km)
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    rating_avg NUMERIC(3,2) NOT NULL DEFAULT 5.00,
    total_trips INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Driver-Business Relationships (Strict Zero-Knowledge Multi-Shop Isolation & Flexible Compensation)
CREATE TABLE business_driver_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    driver_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contract_type VARCHAR(30) NOT NULL, -- FIXED_SALARY, PER_TASK, PER_KM, HYBRID_SALARY_TASK, HYBRID_KM_TASK, CUSTOM
    salary_monthly NUMERIC(10,2) DEFAULT 0.00,
    per_task_amount NUMERIC(10,2) DEFAULT 0.00,
    per_km_amount NUMERIC(10,2) DEFAULT 0.00,
    base_fare NUMERIC(10,2) DEFAULT 0.00,
    surge_bonus_multiplier NUMERIC(3,2) DEFAULT 1.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_id, driver_user_id) -- Unique per shop-driver pair (Zero-knowledge isolation)
);

-- 5. TAXONOMY & PRODUCT CATALOG
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(120) UNIQUE NOT NULL,
    parent_id UUID REFERENCES categories(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID NOT NULL REFERENCES categories(id),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    unit VARCHAR(20) NOT NULL, -- KG, GM, LTR, PACK, PCS
    image_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE business_products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    selling_price NUMERIC(12,2) NOT NULL,
    mrp NUMERIC(12,2) NOT NULL,
    stock_qty INT NOT NULL DEFAULT 0,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_id, product_id)
);

-- 6. CUSTOMER SAVED ADDRESSES
CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label VARCHAR(50) NOT NULL, -- HOME, WORK, OTHER
    address_line TEXT NOT NULL,
    landmark VARCHAR(150),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geom GEOMETRY(Point, 4326),
    is_default BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_addresses_geom ON addresses USING GIST (geom);

-- 7. ORDERS & SNAPSHOTS
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE RESTRICT,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status VARCHAR(30) NOT NULL DEFAULT 'PLACED', -- PLACED, ACCEPTED, PREPARING, READY_FOR_PICKUP, COMPLETED, CANCELLED
    item_total NUMERIC(12,2) NOT NULL,
    delivery_fee NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(12,2) NOT NULL,
    delivery_address_id UUID REFERENCES addresses(id),
    payment_mode VARCHAR(30) NOT NULL DEFAULT 'CASH_ON_DELIVERY', -- CASH_ON_DELIVERY, UPI_QR, ONLINE, DUES_KHATA
    payment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, PAID, ADDED_TO_KHATA
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    business_product_id UUID REFERENCES business_products(id),
    product_name_snapshot VARCHAR(200) NOT NULL,
    unit_price_snapshot NUMERIC(12,2) NOT NULL,
    quantity INT NOT NULL,
    line_total NUMERIC(12,2) NOT NULL
);

-- 8. UNIVERSAL TASK ENGINE
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_type VARCHAR(50) NOT NULL, -- DELIVERY, CAB_BOOKING, SHOPPING_REQUEST, WASHING, PLUMBER, SCHOOL_TRIP
    business_id UUID REFERENCES businesses(id),
    customer_user_id UUID NOT NULL REFERENCES users(id),
    order_id UUID REFERENCES orders(id),
    status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED', 
    -- DRAFT, REQUESTED, BROADCASTING, ASSIGNED, EN_ROUTE_PICKUP, AT_PICKUP, PICKED_UP, EN_ROUTE_DROP, AT_DROP, COMPLETED, CANCELLED
    pickup_address_text TEXT NOT NULL,
    pickup_latitude DOUBLE PRECISION NOT NULL,
    pickup_longitude DOUBLE PRECISION NOT NULL,
    pickup_geom GEOMETRY(Point, 4326),
    drop_address_text TEXT NOT NULL,
    drop_latitude DOUBLE PRECISION NOT NULL,
    drop_longitude DOUBLE PRECISION NOT NULL,
    -- Dual OTP Verification (Configurable per task type / business policy)
    pickup_otp VARCHAR(6),
    is_pickup_otp_required BOOLEAN NOT NULL DEFAULT FALSE,
    pickup_verified_at TIMESTAMPTZ,
    drop_otp VARCHAR(6),
    is_drop_otp_required BOOLEAN NOT NULL DEFAULT TRUE,
    drop_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tasks_pickup_geom ON tasks USING GIST (pickup_geom);
CREATE INDEX idx_tasks_status ON tasks(status);

-- Task Assignments (With Atomic Locking & Device Binding)
CREATE TABLE task_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    driver_user_id UUID NOT NULL REFERENCES users(id),
    vehicle_id UUID REFERENCES vehicles(id), -- Specific vehicle used for this trip/delivery!
    device_id VARCHAR(150) NOT NULL, -- Specific device used to accept & execute this task (prevents 2 devices running 1 task!)
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(task_id, is_active) -- Guarantees at most ONE active driver per task!
);

-- Driver Broadcast Responses & Rejection Isolation
CREATE TABLE task_driver_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    driver_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    response VARCHAR(20) NOT NULL, -- ACCEPTED, REJECTED, EXPIRED
    rejection_reason TEXT,
    responded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(task_id, driver_user_id)
);

-- 9. SHARE-TO-TRACK TOKENS (In-App & Public Sharing)
CREATE TABLE tracking_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    shared_by_user_id UUID NOT NULL REFERENCES users(id),
    token VARCHAR(64) UNIQUE NOT NULL, -- Secure random cryptographic hash
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tracking_shares_token ON tracking_shares(token);

-- 10. REALTIME CHAT (SignalR Backed)
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    conversation_type VARCHAR(30) NOT NULL, -- CUSTOMER_DRIVER, CUSTOMER_SHOP, SUPPORT
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE conversation_participants (
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY(conversation_id, user_id)
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_user_id UUID NOT NULL REFERENCES users(id),
    message_type VARCHAR(20) NOT NULL DEFAULT 'TEXT', -- TEXT, IMAGE, LOCATION
    body TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);

-- 11. LIVEKIT CALL SESSIONS
CREATE TABLE call_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    room_name VARCHAR(100) UNIQUE NOT NULL,
    caller_user_id UUID NOT NULL REFERENCES users(id),
    receiver_user_id UUID NOT NULL REFERENCES users(id),
    status VARCHAR(20) NOT NULL DEFAULT 'INITIATED', -- INITIATED, CONNECTED, ENDED, MISSED
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0
);

-- 12. RATINGS, INVOICES & DRIVER EARNINGS
CREATE TABLE ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    from_user_id UUID NOT NULL REFERENCES users(id),
    to_user_id UUID NOT NULL REFERENCES users(id),
    score INT NOT NULL CHECK(score BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id),
    task_id UUID REFERENCES tasks(id),
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    subtotal NUMERIC(12,2) NOT NULL,
    tax_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    delivery_charge NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    grand_total NUMERIC(12,2) NOT NULL,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE driver_earnings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    driver_user_id UUID NOT NULL REFERENCES users(id),
    business_id UUID REFERENCES businesses(id),
    base_earning NUMERIC(10,2) NOT NULL,
    distance_km NUMERIC(6,2) NOT NULL,
    km_earning NUMERIC(10,2) NOT NULL,
    bonus NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    total_earning NUMERIC(10,2) NOT NULL,
    is_settled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. AUDIT LOGS (Who Did What, When, and From Where)
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_user_id UUID REFERENCES users(id),
    role VARCHAR(50),
    entity_type VARCHAR(50) NOT NULL, -- TASK, ORDER, DRIVER, BUSINESS, INVOICE
    entity_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL, -- CREATED, STATUS_CHANGED, ACCEPTED, REJECTED, OTP_VERIFIED, CANCELLED
    ip_address VARCHAR(45),
    user_agent TEXT,
    old_state_json JSONB,
    new_state_json JSONB,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_user_id, created_at DESC);

-- 14. COMPREHENSIVE COMMUNICATIONS LOG (Mail, SMS, WhatsApp, Push)
CREATE TABLE communication_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel VARCHAR(30) NOT NULL, -- SMS, WHATSAPP, EMAIL, PUSH_NOTIFICATION
    recipient_identifier VARCHAR(255) NOT NULL, -- Phone number, email address, or FCM device token
    recipient_user_id UUID REFERENCES users(id),
    related_task_id UUID REFERENCES tasks(id),
    template_code VARCHAR(100),
    subject TEXT,
    message_body TEXT NOT NULL,
    provider_name VARCHAR(50), -- Twilio, Meta WhatsApp API, SendGrid, Firebase
    provider_message_id VARCHAR(150),
    delivery_status VARCHAR(30) NOT NULL DEFAULT 'SENT', -- SENT, DELIVERED, FAILED, BOUNCED
    failure_reason TEXT,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at TIMESTAMPTZ
);
CREATE INDEX idx_comm_logs_recipient ON communication_logs(recipient_identifier, sent_at DESC);
CREATE INDEX idx_comm_logs_task ON communication_logs(related_task_id);

-- 15. DRIVER INTER-CITY ROUTE BANNERS (Jaipur -> Delhi etc. via AI Query Box)
CREATE TABLE driver_trip_offers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vehicle_id UUID REFERENCES vehicles(id),
    origin_city VARCHAR(100) NOT NULL, -- e.g. "Jaipur"
    destination_city VARCHAR(100) NOT NULL, -- e.g. "Delhi"
    origin_lat DOUBLE PRECISION,
    origin_lng DOUBLE PRECISION,
    destination_lat DOUBLE PRECISION,
    destination_lng DOUBLE PRECISION,
    departure_time TIMESTAMPTZ NOT NULL, -- e.g. Kal 11:00 AM
    price_per_seat NUMERIC(10,2) NOT NULL, -- e.g. 1500.00
    total_seats INT NOT NULL DEFAULT 3,
    available_seats INT NOT NULL DEFAULT 3,
    description TEXT, -- e.g. "Ac sedan cab available, luggage space available"
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, FULL, COMPLETED, CANCELLED
    ai_prompt_original TEXT, -- Original query entered in AI box
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_trip_offers_route ON driver_trip_offers(origin_city, destination_city, departure_time);

-- 16. KHATA / DUES & STORE CREDIT LEDGER (Udhar Management per Customer)
CREATE TABLE business_customer_khata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_dues_enabled BOOLEAN NOT NULL DEFAULT FALSE, -- Toggled ON/OFF by shopkeeper for trusted customers
    credit_limit NUMERIC(12,2) NOT NULL DEFAULT 2000.00, -- Maximum allowed unpaid credit (e.g. ₹5,000)
    current_due_balance NUMERIC(12,2) NOT NULL DEFAULT 0.00, -- Current outstanding dues
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(business_id, customer_user_id)
);

CREATE TABLE khata_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    khata_id UUID NOT NULL REFERENCES business_customer_khata(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id),
    transaction_type VARCHAR(30) NOT NULL, -- DUES_ADDED (Order purchased on credit), PAYMENT_RECEIVED (Customer paid back)
    amount NUMERIC(12,2) NOT NULL,
    payment_mode VARCHAR(30), -- CASH, UPI_QR, BANK_TRANSFER
    balance_after NUMERIC(12,2) NOT NULL,
    recorded_by_user_id UUID NOT NULL REFERENCES users(id), -- Shopkeeper or Delivery boy who accepted payment
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_khata_tx ON khata_transactions(khata_id, created_at DESC);

-- 17. SOCIAL MEETUPS & HYPERLOCAL DATING ("Free for Coffee Tomorrow 5 PM")
CREATE TABLE social_meetups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    meetup_type VARCHAR(40) NOT NULL, -- COFFEE_DATE, SPORTS_BUDDY, CASUAL_HANGOUT, WALKING_BUDDY
    title VARCHAR(150) NOT NULL, -- e.g. "Free for Coffee Tomorrow 5 PM at Blue Tokai"
    description TEXT,
    preferred_gender VARCHAR(20), -- ANY, FEMALE, MALE
    min_age INT DEFAULT 18,
    max_age INT DEFAULT 50,
    meetup_venue_name VARCHAR(150) NOT NULL, -- Public Cafe / Mall / Park (Never private home address)
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geom GEOMETRY(Point, 4326),
    scheduled_at TIMESTAMPTZ NOT NULL, -- e.g. Tomorrow 5:00 PM
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN', -- OPEN, MATCHED, EXPIRED, CANCELLED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_meetups_geom ON social_meetups USING GIST (geom);

CREATE TABLE meetup_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meetup_id UUID NOT NULL REFERENCES social_meetups(id) ON DELETE CASCADE,
    requester_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    intro_message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, ACCEPTED, REJECTED
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(meetup_id, requester_user_id)
);

-- 18. COMMUNITY CLASSIFIEDS & LOCAL BOUNTIES ("Need Teacher for 5yo child, budget ₹600/mo")
CREATE TABLE community_classifieds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL, -- HOME_TUTOR, MAID_COOK, BABYSITTER, PET_CARE, APPLIANCE_REPAIR
    title VARCHAR(200) NOT NULL, -- e.g. "Need home tutor for 5-year-old child"
    description TEXT NOT NULL,
    target_child_age INT, -- e.g. 5
    budget_amount NUMERIC(10,2) NOT NULL, -- e.g. 600.00
    budget_frequency VARCHAR(20) NOT NULL DEFAULT 'MONTHLY', -- MONTHLY, PER_HOUR, PER_TASK
    preferred_timing VARCHAR(100), -- e.g. "Evening 4 PM to 5 PM"
    location_text TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geom GEOMETRY(Point, 4326),
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN', -- OPEN, ASSIGNED, COMPLETED, CLOSED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_classifieds_geom ON community_classifieds USING GIST (geom);

CREATE TABLE classified_proposals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    classified_id UUID NOT NULL REFERENCES community_classifieds(id) ON DELETE CASCADE,
    provider_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    proposed_rate NUMERIC(10,2) NOT NULL,
    proposal_message TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, ACCEPTED, REJECTED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(classified_id, provider_user_id)
);

-- 19. RECURRING SUBSCRIPTIONS (Daily Morning Milk, Newspaper, Tiffin)
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity INT NOT NULL DEFAULT 1,
    frequency VARCHAR(30) NOT NULL DEFAULT 'DAILY', -- DAILY, ALTERNATE_DAYS, WEEKDAYS_ONLY
    delivery_time_slot VARCHAR(50) NOT NULL DEFAULT '06:00-07:30 AM', -- 06:00 AM - 07:30 AM auto-dispatch slot
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, PAUSED_VACATION, CANCELLED
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 19.1 SUBSCRIPTION PAUSES (Vacation Mode: "Kal se 5 din tak milk delivery pause")
CREATE TABLE subscription_pauses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    pause_start_date DATE NOT NULL,
    pause_end_date DATE NOT NULL,
    reason TEXT DEFAULT 'Vacation / Out of Station',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_sub_pauses_dates ON subscription_pauses(subscription_id, pause_start_date, pause_end_date);

-- 19.2 SUBSCRIPTION DAILY DELIVERY LOGS & MONTH-END KHATA SYNC
CREATE TABLE subscription_daily_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    delivery_date DATE NOT NULL,
    quantity INT NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    total_price NUMERIC(10,2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING', -- DELIVERED, SKIPPED_VACATION, FAILED
    driver_user_id UUID REFERENCES users(id),
    delivered_at TIMESTAMPTZ,
    billed_to_khata BOOLEAN NOT NULL DEFAULT FALSE,
    khata_transaction_id UUID REFERENCES khata_transactions(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(subscription_id, delivery_date)
);
CREATE INDEX idx_sub_logs_date ON subscription_daily_logs(subscription_id, delivery_date, status);

-- 20. EMERGENCY SOS & SAFETY ALERTS
CREATE TABLE sos_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id UUID REFERENCES tasks(id),
    meetup_id UUID REFERENCES social_meetups(id),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    geom GEOMETRY(Point, 4326),
    alert_type VARCHAR(50) NOT NULL DEFAULT 'EMERGENCY_SOS', -- EMERGENCY_SOS, ROUTE_DEVIATION, DRIVER_PANIC
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, RESOLVED, FALSE_ALARM
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- 21. CUSTOMER MULTI-SHOP RFQ & QUOTE REQUESTS ("1 Shop, 3 Shops, ya Open Network")
CREATE TABLE customer_rfqs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rfq_mode VARCHAR(30) NOT NULL, -- DIRECT_SINGLE_SHOP, MULTI_SHOP_SELECTIVE, OPEN_NETWORK_BROADCAST
    target_business_ids UUID[], -- Array of specific shop IDs (e.g. 1 shop or 3 selected shops). NULL if OPEN_NETWORK
    raw_prompt TEXT NOT NULL, -- e.g. "mujhe 5kg aaloo, 2 kg pyag, 1 kg tomato chahiye tino se rate mango"
    items_json JSONB NOT NULL, -- Standardized structured JSON: [{"item": "Potato", "qty": 5, "unit": "kg"}]
    delivery_address_id UUID REFERENCES addresses(id),
    radius_km DOUBLE PRECISION DEFAULT 5.0,
    ai_detected_intent VARCHAR(30) NOT NULL, -- RATE_INQUIRY (Rate mang rha h) vs DIRECT_ORDER (Direct order lga rha h)
    status VARCHAR(30) NOT NULL DEFAULT 'OPEN', -- OPEN, QUOTES_RECEIVED, CONVERTED_TO_ORDER, EXPIRED, CANCELLED
    winning_business_id UUID REFERENCES businesses(id),
    converted_order_id UUID REFERENCES orders(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX idx_rfqs_customer ON customer_rfqs(customer_user_id, created_at DESC);

-- 22. RFQ BUSINESS QUOTES (Itemized Rates Submitted by Vendors)
CREATE TABLE rfq_business_quotes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rfq_id UUID NOT NULL REFERENCES customer_rfqs(id) ON DELETE CASCADE,
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    itemized_rates_json JSONB NOT NULL, -- [{"item": "Potato", "unit_price": 30.0, "line_total": 150.0}]
    total_price NUMERIC(12,2) NOT NULL, -- e.g. 1000.00
    estimated_delivery_minutes INT DEFAULT 30,
    notes TEXT, -- e.g. "Taaza pahadi aaloo aur laal tamatar available hai"
    status VARCHAR(20) NOT NULL DEFAULT 'SUBMITTED', -- SUBMITTED, ACCEPTED, REJECTED, EXPIRED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(rfq_id, business_id)
);
CREATE INDEX idx_rfq_quotes_rfq ON rfq_business_quotes(rfq_id, total_price ASC);

-- 23. USER DEVICE SESSIONS & CONCURRENT LOGIN RESTRICTIONS
CREATE TABLE user_device_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(150) NOT NULL, -- Unique client device hardware ID
    device_name VARCHAR(150), -- e.g. "Samsung Galaxy S22", "iPhone 14"
    platform VARCHAR(30) NOT NULL, -- ANDROID, IOS, WEB
    ip_address VARCHAR(50),
    user_agent TEXT,
    fcm_token TEXT,
    jwt_jti VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    logged_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ
);
CREATE INDEX idx_user_sessions ON user_device_sessions(user_id, is_active);
CREATE INDEX idx_user_device_id ON user_device_sessions(device_id);
```

---

### 2.2 Dedicated Telemetry Database (`shopconnector_telemetry`) DDL

This separate database handles millions of GPS points without locking or slowing down relational business tables:

```sql
CREATE DATABASE shopconnector_telemetry;
\c shopconnector_telemetry;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- High-throughput location history (Partitioned by Month)
CREATE TABLE location_history (
    id UUID DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL,
    driver_user_id UUID NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    geom GEOMETRY(Point, 4326),
    PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);

-- Example Monthly Partitions (Auto-generated by background worker)
CREATE TABLE location_history_y2026m09 PARTITION OF location_history
    FOR VALUES FROM ('2026-09-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');
CREATE TABLE location_history_y2026m10 PARTITION OF location_history
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');

CREATE INDEX idx_location_history_task_time ON location_history (task_id, recorded_at DESC);
CREATE INDEX idx_location_history_driver_time ON location_history (driver_user_id, recorded_at DESC);
CREATE INDEX idx_location_history_geom ON location_history USING GIST (geom);
```

---

## 3. High-Performance Realtime Telemetry & Smooth Movement Architecture

To make the cab/driver icon move **as smoothly as Uber/Ola** on Flutter and React without jumping or stuttering:

```
+----------------------------------------------------------------------------------------------------+
|                                    SMOOTH TELEMETRY PIPELINE                                       |
|                                                                                                    |
|  [Driver Phone]                                                                                    |
|       | (High-frequency GPS: 2s interval)                                                          |
|       v                                                                                            |
|  [Mosquitto Local Broker (Port 1883)]                                                              |
|       | Topic: tracking/v1/{tenantId}/driver/{driverId}/location                                   |
|       v                                                                                            |
|  [ASP.NET Core Tracking Ingestion Worker]                                                          |
|       |                                                                                            |
|       +--> Update Redis Cache: HSET "latest_loc:{driverId}" lat lng heading speed ts               |
|       +--> Push to SignalR Hub: "TrackingHub.BroadcastLocationToTask(taskId, point)"               |
|       +--> (Every 30s / on Stop): Batch Insert into shopconnector_telemetry.location_history       |
|                                                                                                    |
|  [Customer / Shared User Flutter Mobile App]                                                       |
|       | Receives SignalR delta                                                                     |
|       v                                                                                            |
|  +----------------------------------------------------------------------------------------------+  |
|  | 1. Kalman Filter -> Eliminates GPS drift & jump while vehicle is stopped at traffic lights   |  |
|  | 2. LatLng Interpolation (Tween AnimationController, duration: 2000ms, Curves.linear)        |  |
|  | 3. Shortest-Angle Bearing Rotation (Transforms cab icon smoothly towards new direction)     |  |
|  | 4. Snap-to-Polyline (Snaps interpolated coordinates onto OSRM calculated route)             |  |
|  +----------------------------------------------------------------------------------------------+  |
+----------------------------------------------------------------------------------------------------+
```

### Flutter Smooth Movement Implementation (Dart Code Reference)

```dart
class SmoothMarkerAnimator {
  final LatLng startPosition;
  final LatLng targetPosition;
  final double startRotation;
  final double targetRotation;
  final AnimationController controller;

  SmoothMarkerAnimator({
    required this.startPosition,
    required this.targetPosition,
    required this.startRotation,
    required this.targetRotation,
    required this.controller,
  });

  // Linear Interpolation for Latitude/Longitude
  LatLng getCurrentPosition(double t) {
    final lat = startPosition.latitude + (targetPosition.latitude - startPosition.latitude) * t;
    final lng = startPosition.longitude + (targetPosition.longitude - startPosition.longitude) * t;
    return LatLng(lat, lng);
  }

  // Shortest delta angle rotation (prevents 350 -> 10 deg spinning 340 degrees backward)
  double getCurrentRotation(double t) {
    double delta = (targetRotation - startRotation) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return (startRotation + delta * t) % 360;
  }
}
```

### 3.1 Offline-First Telemetry Buffering & Batch Synchronization

Driver applications operate in real-world conditions with basements, tunnels, and weak cellular connectivity. Tracking **must never drop data**.

```
[Weak / No Cellular Signal]
       |
       v
[Flutter Driver App buffers GPS points in local SQLite / Hive]
       | Schema: { task_id, latitude, longitude, speed, heading, accuracy, recorded_at, seq }
       | Up to 5,000 points buffered offline with zero memory leak
       |
[Network Connectivity Restored (Wi-Fi / 4G / 5G)]
       |
       v
[App Background Flush Worker triggers Batch Sync]
       |
       v
[POST /api/v1/tracking/batch-sync]
       | Payload: Batches of 50–100 GPS points with Idempotency-Key
       |
       +--> Backend Bulk Inserts into shopconnector_telemetry.location_history (COPY / Bulk Insert)
       +--> Backend updates Redis latest_loc:{driverId} with the newest recorded point
       +--> If offline task status event occurred (e.g. OTP verified offline), it syncs with TOP PRIORITY!
       +--> Customer / Shop live map immediately catches up with complete path breadcrumbs!
```

---

### 3.2 Pluggable Distance & Duration Engine: Haversine Formula with Urban Road Factor (Phase 1 Default)

To eliminate external API costs (Google Distance Matrix API billing) and huge routing graph downloads (OSRM 10GB+ map files) during initial development, the platform uses a high-speed **Haversine Distance & Duration Engine** with a pluggable provider interface:

```
+----------------------------------------------------------------------------------------------------+
|                             PLUGGABLE DISTANCE & DURATION PIPELINE                                 |
|                                                                                                    |
|  [Origin (Lat1, Lng1)] -----------------------------------------> [Destination (Lat2, Lng2)]       |
|                                           |                                                        |
|                                           v                                                        |
|                  +-------------------------------------------------+                               |
|                  |          IDistanceMatrixService Interface       |                               |
|                  +-------------------------------------------------+                               |
|                                           |                                                        |
|             +-----------------------------+-----------------------------+                          |
|             |                                                           |                          |
|             v (Phase 1: Default Active)                                 v (Future Swappable)       |
|  +-------------------------------------+             +--------------------------------------+      |
|  |     HaversineDistanceService        |             |   OsrmDistanceService / GoogleMaps   |      |
|  | - Pure in-memory math (< 0.05 ms)   |             | - Exact road turn-by-turn routing    |      |
|  | - Urban Tortuosity Multiplier: 1.30 |             | - Requires self-hosted OSRM server   |      |
|  | - Avg City Speed: 25 km/h + buffer  |             |   or Google Maps API Key             |      |
|  | - ZERO Cloud Cost & ZERO Map PBF    |             +--------------------------------------+      |
|  +-------------------------------------+                                                           |
+----------------------------------------------------------------------------------------------------+
```

#### 1. Mathematical Haversine Formula:
The straight-line spherical distance between two points on Earth:
$$d = 2R \cdot \arcsin\left(\sqrt{\sin^2\left(\frac{\Delta \phi}{2}\right) + \cos(\phi_1) \cdot \cos(\phi_2) \cdot \sin^2\left(\frac{\Delta \lambda}{2}\right)}\right)$$
where $R = 6,371\text{ km}$ (Earth mean radius), $\phi = \text{latitude in radians}$, $\lambda = \text{longitude in radians}$.

#### 2. Urban Road Tortuosity Multiplier (Indian City Traffic):
Straight-line displacement rarely reflects real-world city streets with turns and flyovers. The engine applies an empirical **Urban Tortuosity Multiplier** of $\mathbf{1.30}$:
$$\text{Estimated Road Distance (km)} = \text{Haversine Distance} \times 1.30$$

#### 3. Duration & ETA Calculation:
$$\text{Estimated Travel Minutes} = \left(\frac{\text{Estimated Road Distance (km)}}{\text{Average Speed (25 km/h)}} \times 60\right) + 3\text{ Minutes Dispatch Buffer}$$

#### 4. C# Implementation (.NET Core 8 `IDistanceMatrixService`):
```csharp
public interface IDistanceMatrixService
{
    Task<(double distanceKm, int durationMinutes)> CalculateDistanceAndDurationAsync(
        double lat1, double lng1, double lat2, double lng2, string vehicleType = "BIKE");
}

public class HaversineDistanceService : IDistanceMatrixService
{
    private const double EarthRadiusKm = 6371.0;
    private const double UrbanRoadFactor = 1.30; // 30% detour compensation
    private const double BikeSpeedKmh = 25.0;     // Average city two-wheeler speed
    private const double CabSpeedKmh = 20.0;      // Average city four-wheeler speed

    public Task<(double distanceKm, int durationMinutes)> CalculateDistanceAndDurationAsync(
        double lat1, double lng1, double lat2, double lng2, string vehicleType = "BIKE")
    {
        double dLat = ToRadians(lat2 - lat1);
        double dLng = ToRadians(lng2 - lng1);

        double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                   Math.Cos(ToRadians(lat1)) * Math.Cos(ToRadians(lat2)) *
                   Math.Sin(dLng / 2) * Math.Sin(dLng / 2);

        double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        double straightDistance = EarthRadiusKm * c;
        
        double roadDistance = Math.Round(straightDistance * UrbanRoadFactor, 2);
        double speed = vehicleType.ToUpper() == "CAB" ? CabSpeedKmh : BikeSpeedKmh;
        int durationMinutes = (int)Math.Ceiling((roadDistance / speed) * 60) + 3; // +3 min pickup buffer

        return Task.FromResult((roadDistance, durationMinutes));
    }

    private static double ToRadians(double degrees) => degrees * (Math.PI / 180.0);
}
```

#### 5. Clean Config-Driven Provider Swap:
In `appsettings.json`:
```json
{
  "Routing": {
    "DistanceProvider": "Haversine", // "Haversine" (Phase 1 default) | "OSRM" | "Google"
    "OsrmBaseUrl": "http://127.0.0.1:5000",
    "GoogleApiKey": ""
  }
}
```
When transitioning to production later, simply change `"DistanceProvider": "OSRM"` or `"Google"` without altering a single controller or business entity!

---

## 4. Multi-Shop Driver Privacy & Zero-Knowledge Isolation

A delivery boy can freely work for multiple shops simultaneously, but **strict business privacy** is maintained:

```
                  +-----------------------------------+
                  |     Delivery Boy (Ravi - Phone)   |
                  +-----------------------------------+
                                    |
          +-------------------------+-------------------------+
          |                                                   |
          v                                                   v
+-------------------------+                         +-------------------------+
|     Shop 1 (Kirana)     |                         |    Shop 2 (Pharmacy)    |
| - Adds Ravi by phone    |                         | - Adds Ravi by phone    |
| - Contract: Per Task    |                         | - Contract: Monthly     |
| - ZERO KNOWLEDGE of     |                         | - ZERO KNOWLEDGE of     |
|   Ravi working at Shop 2|                         |   Ravi working at Shop 1|
+-------------------------+                         +-------------------------+
```

### 1. Zero-Knowledge Shop Isolation Rules
- **No Cross-Shop Visibility**: When Shop 1 opens its driver roster, the backend executes `SELECT * FROM business_driver_relationships WHERE business_id = @Shop1Id`. Shop 1 **CANNOT** see if Ravi also delivers for Shop 2, Shop 3, or a competitor.
- **Independent Contracts**: Shop 1 can pay Ravi ₹30 per order, while Shop 2 pays Ravi a fixed ₹12,000 monthly salary. Neither shop has access to the other shop's contractual terms.

### 2. Driver Experience & Clear Origin Identification
- In Ravi's Driver App, he sees all shops he has active memberships with (`My Businesses -> Shop 1, Shop 2`).
- **When a Task/Booking Arrives**: The broadcast notification explicitly displays:
  - **Originating Shop**: *"New Order from Shop 1 (Gupta Kirana Store)"*
  - **Pickup Address**: Shop 1 Location
  - **Delivery Destination**: Customer Drop Address
  - **Task Earning**: Calculated strictly according to Shop 1's contract with Ravi!

### 3. Personal Dedicated Rider vs. "Connect with Open Network" Toggle

A critical real-world capability is separating dedicated store deliveries from open public rides:

```
[Shopkeeper adds Rider by Phone]
            |
            v
[Default Status: Personal Dedicated Rider (is_network_enabled = FALSE)]
- Rider ONLY receives delivery tasks dispatched by linked Shop 1 / Shop 2
- Rider does NOT receive random customer cab requests or generic errands
            |
            v (Rider wants extra earnings during idle hours / evenings)
[Rider flips toggle in App: "Connect with Open Network" (is_network_enabled = TRUE)]
            |
            +--> Rider STILL receives priority orders from linked shops
            +--> PLUS: Rider now receives direct broadcast requests from nearby customers!
            +--> Rider icon becomes visible on nearby customers' live home map!
```

### 4. Customer Geolocation & Spatial Proximity Engine

To enable hyper-local commerce and instant mobility:
1. **Device GPS Auto-Detection**:
   - Flutter app requests device location permissions and fetches current `(customerLat, customerLng)`.
2. **Nearby Shop Discovery Query (PostGIS)**:
   - Queries shops within radius (e.g. 5–10 km) sorted by real-world road distance and ETA:
   ```sql
   SELECT id, name, business_type, address_text, latitude, longitude,
          ROUND((ST_Distance(geom, ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography) / 1000)::numeric, 2) AS distance_km
   FROM businesses
   WHERE is_active = TRUE 
     AND ST_DWithin(geom, ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography, 10000)
   ORDER BY distance_km ASC;
   ```
3. **Live Nearby Rider Visualization (Uber/Rapido Style)**:
   - Customer map streams nearby online riders who have enabled `is_network_enabled = TRUE`:
   - Redis Geospatial query: `GEORADIUS drivers:available {customerLng} {customerLat} 3 km WITHCOORD`
   - Customer sees live moving bike/cab icons around their neighborhood in real time!

### 5. Multi-Vehicle Garage & Single Active Vehicle Enforcement

A single driver can register multiple vehicles across different categories:

```
+-----------------------------------------------------------------------------+
|                          DRIVER'S REGISTERED GARAGE                         |
|                                                                             |
|  [Vehicle 1: Hero Splendor (BIKE) - Plate: BR-01-AB-1234] -> Active: ON     |
|  [Vehicle 2: Maruti Dzire (CAB)   - Plate: BR-01-CD-5678] -> Standby        |
|  [Vehicle 3: Piaggio Ape (AUTO)   - Plate: BR-01-EF-9012] -> Standby        |
+-----------------------------------------------------------------------------+
```

#### Enforcement Rules:
1. **Exactly One Active Vehicle**: A driver can ONLY be `ON_DUTY` on one active vehicle at any given time.
2. **Duty Toggle Flow**:
   - Driver taps "Go Online".
   - If multiple vehicles are registered, app shows a selection modal: *"Which vehicle are you operating today?"*
   - Driver selects active vehicle -> Calls `POST /api/v1/drivers/duty` with `{ "duty_status": "ON_DUTY", "vehicle_id": "uuid" }`.
   - Backend updates `driver_profiles.active_vehicle_id = vehicle_id`.
3. **Task Compatibility Filtering**:
   - If active vehicle is `BIKE`: Driver receives food delivery, grocery packages, and bike taxi requests.
   - If active vehicle is `CAB_SEDAN`: Driver receives 4-seater passenger cab bookings.
4. **Customer Transparency**:
   - `task_assignments.vehicle_id` records the exact vehicle. Customer tracking screen displays:
     *"Ravi is arriving in Hero Splendor (Black) | BR-01-AB-1234"*.

### 6. Driver Configurable Operating Radii Engine (Pickup vs. Delivery)

Drivers have complete autonomy over their travel boundaries. In the Driver App settings (`Profile -> Operating Preferences`), drivers can independently configure two distinct radii:

```
[Driver Current Location]
           |
           +---- (Must be <= max_pickup_radius_km, e.g. 1 KM) ----> [Pickup: Shop / Customer]
                                                                             |
                                                                             +---- (Must be <= max_delivery_radius_km, e.g. 10 KM) ----> [Drop Destination]
```

#### Two Independent Controls:
1. **Pickup Acceptance Radius (`max_pickup_radius_km`)**:
   - *"Main apne paas se kitni door tak booking accept karunga?"* (e.g. 1 km).
   - Prevents drivers from having to travel far across town just to pick up a small order.
2. **Delivery Trip Radius (`max_delivery_radius_km`)**:
   - *"Main kitni door tak delivery le jaa sakta hoon?"* (e.g. 10 km).
   - Allows local drivers to restrict long-distance trips or allow highway drivers to take 25+ km deliveries.

#### Spatial Dispatch Query Filter (PostGIS):
```sql
SELECT dp.user_id
FROM driver_profiles dp
JOIN latest_locations ll ON ll.subject_id = dp.user_id AND ll.subject_type = 'DRIVER'
WHERE dp.duty_status = 'FREE'
  -- 1. Pickup Check: Driver Current Position -> Task Pickup Point
  AND ST_DWithin(ll.geom, @pickup_geom, dp.max_pickup_radius_km * 1000)
  -- 2. Delivery Check: Task Pickup Point -> Task Drop Point
  AND ST_DWithin(@pickup_geom, @drop_geom, dp.max_delivery_radius_km * 1000);
```

### 7. Granular Driver Operational Status Lifecycle

A driver's operational state progresses smoothly through 6 deterministic lifecycle states:

```
               +-------------------------------------------------------+
               |                       OFF_DUTY                        |
               +-------------------------------------------------------+
                                           |
                                 (Driver goes Online)
                                           v
               +-------------------------------------------------------+
               |                   FREE (Available)                    | <----+
               +-------------------------------------------------------+      |
                                           |                                  |
                                (Accepts Task Broadcast)                      |
                                           v                                  |
               +-------------------------------------------------------+      |
               |     EN_ROUTE_PICKUP (On-Duty Going to Pickup)         |      |
               +-------------------------------------------------------+      |
                                           |                                  |
                                (Arrived at Pickup)                           |
                                           v                                  |
               +-------------------------------------------------------+      |
               |             AT_PICKUP (At Pickup Point)               |      |
               +-------------------------------------------------------+      |
                                           |                                  |
                           (Pickup OTP Verified / Items Loaded)               |
                                           v                                  |
               +-------------------------------------------------------+      |
               |                      PICKED_UP                        |      |
               +-------------------------------------------------------+      |
                                           |                                  |
                                 (Arrived at Drop Point)                      |
                                           v                                  |
               +-------------------------------------------------------+      |
               |                 AT_DROP (Drop Off Location)           |      |
               +-------------------------------------------------------+      |
                                           |                                  |
                            (Drop OTP Verified / Delivered)                   |
                                           +----------------------------------+
```

| Lifecycle State | Description & System Action |
| :--- | :--- |
| **`OFF_DUTY`** | Driver is offline and resting. Receives zero notifications or telemetry pings. |
| **`FREE`** (Available) | Driver is online, idle, and eligible to receive nearby broadcast cards within their radii. |
| **`EN_ROUTE_PICKUP`** | Driver accepted task and is actively driving towards the shop/customer pickup location. |
| **`AT_PICKUP`** | Driver arrived at pickup location. Waiting for goods packaging / passenger boarding & Pickup OTP. |
| **`PICKED_UP`** | Pickup OTP verified. Goods/passenger onboard. Live OSRM turn-by-turn routing to drop starts. |
| **`AT_DROP`** | Driver reached customer drop location. Awaiting customer Drop OTP handoff. |

---

### 8. Driver Inter-City Route Banners via AI Query Box & Customer Broadcast

Drivers can schedule one-way inter-city trips or empty return legs (e.g. *Jaipur to Delhi*) to maximize earnings:

```
[Driver enters text or voice in App AI Box]
"Jaipur se Delhi ke liye available hoon kal 11 bje se 1500 lenge, 3 seat khali hai"
                              |
                              v
[Python AI Agent (Grok LLM) parses intent & calls create_driver_trip_banner()]
                              |
                              +--> Origin: Jaipur | Destination: Delhi | Time: Tomorrow 11:00 AM
                              +--> Fare: ₹1,500/seat | Available Seats: 3
                              |
                              v
[Saved in driver_trip_offers table]
                              |
                              v
[Automated Customer Broadcast Engine]
- In-App Banner displayed on Jaipur customer home screens:
  "Ravi is traveling Jaipur -> Delhi tomorrow at 11:00 AM | ₹1500/seat | [Book Now]"
- Push Notification / WhatsApp alert sent to customers who frequently travel this route!

### 9. Apartment Street Vendor & Daily Grocery Voice AI Ordering (Hindi/Hinglish/English)

In Indian residential apartments and societies, daily vegetable vendors (*sabjiwalas*), fruit sellers, and local kirana shops deliver groceries directly to doorsteps. Instead of navigating complex e-commerce catalogs, residents can place orders completely naturally via voice or free-form text.

#### 9.1 Three Flexible Customer Request Modes

The customer can issue their grocery/vegetable requirement in **3 distinct operational modes**:

```
+----------------------------------------------------------------------------------------------------+
|                                  THREE CUSTOMER REQUEST MODES                                      |
|                                                                                                    |
|  [MODE A: SINGLE SHOP DIRECT ORDER]                                                                |
|  - Customer selects 1 specific favorite shopkeeper / sabjiwala (e.g. "Gupta Kirana").              |
|  - Direct handoff: Order draft is sent exclusively to this shopkeeper.                             |
|                                                                                                    |
|  [MODE B: SELECTIVE MULTI-SHOP RATE QUOTATION (e.g. 2 or 3 Selected Shops)]                        |
|  - Customer selects 2 or 3 specific shops from their neighborhood (e.g. Gupta, Sharma, Verma).     |
|  - System requests itemized rate quotes from all 3 selected shops simultaneously.                  |
|  - Customer compares rates side-by-side on Flutter app and picks the best/cheapest shop.           |
|                                                                                                    |
|  [MODE C: HYPERLOCAL OPEN NETWORK BROADCAST]                                                       |
|  - Customer does not pick specific shops; broadcasts requirement to ALL nearby shops within 3-5km. |
|  - All eligible local vendors receive RFQ alert and submit competitive quotes.                     |
|  - Customer gets the best neighborhood market price with transparent price discovery.              |
+----------------------------------------------------------------------------------------------------+
```

---

#### 9.2 AI Intent Decision Engine: Rate Inquiry vs. Direct Order

When the customer speaks or types their requirement in Hindi, Hinglish, or English, the **Python AI Agent (FastAPI + Grok LLM)** automatically determines the user's intent:

```
[Customer Speaks in App or AI Box]
"Bhaiya mujhe 5kg aaloo, 2 kg pyaz, 1 kg tomato chahiye..."
                              |
                              v
[Python AI Agent analyzes linguistic intent & context]
                              |
       +----------------------+----------------------+
       |                                             |
       v                                             v
[INTENT 1: RATE_INQUIRY]                     [INTENT 2: DIRECT_ORDER]
"Tino dukan se rate mango"                   "Gupta ji ko bolo turant bhej dein"
"Kya bhav chal raha hai?"                    "Jaldi order laga do shaam tak"
       |                                             |
       v                                             v
- Creates customer_rfqs (Mode: B or C)       - Checks if target shop selected (Mode A)
- Pushes RFQ alert to target vendors         - Calls create_order_draft()
- Vendors submit itemized prices             - Prepares cart with live catalog prices
- Flutter app renders Side-by-Side           - Shows 1-tap confirmation card to customer:
  Comparative Price Matrix:                    "Total: ₹980. Confirm Order?"
  + Gupta Store:  ₹980 (ETA 20m)             - Upon tap -> Task assigned & dispatched!
  + Sharma Store: ₹1,000 (ETA 15m)
  + Verma Mart:   ₹1,050 (ETA 30m)
- Customer taps [Accept & Place Order]
  on preferred vendor card!
```

---

#### 9.3 End-to-End Fulfillment & Doorstep Dispatch

```
[Order Confirmed by Customer (Mode A, or winning quote from Mode B/C)]
                                   |
                                   v
[Order Draft sent to Shopkeeper / Street Vendor Mobile Dashboard]
- Shopkeeper reviews parsed item list with 1 tap.
- Inputs / confirms market daily rates (e.g. 5kg Potato @ ₹30 = ₹150, 2kg Onion @ ₹40 = ₹80, 1kg Tomato @ ₹60 = ₹60... Total = ₹1,000).
- Taps [Pack Order] -> [Ready for Delivery].
                                   |
                                   v
[Delivery Boy / Personal Vendor Dispatched]
- Order status transitions to OUT_FOR_DELIVERY.
- Delivery boy carries packed items to apartment door (Flat 402, Tower B).
- Doorstep payment collection flow begins (Cash, UPI QR, or Dues/Khata).
```

---

### 10. Digital Khata / Udhar Ledger & Flexible Doorstep Payment Engine

Local neighborhood trade relies heavily on mutual trust, informal credit (*Udhar / Khata*), and flexible payment collection. The platform formalizes this with a **Zero-Dispute Digital Khata Ledger**:

```
+----------------------------------------------------------------------------------------------------+
|                                 DOORSTEP PAYMENT COLLECTION MATRIX                                 |
|                                                                                                    |
|  Delivery Boy reaches Apartment Doorstep (Total Bill: ₹1,000)                                      |
|                                                                                                    |
|  [OPTION 1: CASH]                                                                                  |
|  - Customer hands over physical currency notes.                                                    |
|  - Delivery boy enters ₹1,000 cash collected -> Taps [Confirm Cash Received].                      |
|                                                                                                    |
|  [OPTION 2: DYNAMIC UPI QR CODE]                                                                   |
|  - Delivery boy taps [Show UPI QR] on mobile screen.                                               |
|  - App renders dynamic QR code encoded with: upi://pay?pa={shopUpiId}&am=1000.00&tr={orderId}      |
|  - Customer scans with GPay / PhonePe / Paytm -> Instant webhook confirmation to API.              |
|                                                                                                    |
|  [OPTION 3: DUES / KHATA (UDHAR) STORE CREDIT]                                                     |
|  * Strictly Gated & Controlled by Shopkeeper! *                                                    |
|                                                                                                    |
|  IF shopkeeper has toggled is_dues_enabled = TRUE for THIS specific customer:                      |
|     AND (current_due_balance + 1000) <= credit_limit:                                              |
|         -> App displays active green button: [Add to Khata / Dues]                                 |
|         -> Delivery boy taps button -> Records transaction in khata_transactions                   |
|         -> Increases current_due_balance by ₹1,000                                                 |
|         -> Instant SMS & WhatsApp receipt sent to Customer:                                        |
|            "₹1,000 added to your Gupta Kirana Khata for Order #492. Outstanding: ₹1,450"          |
|                                                                                                    |
|  IF is_dues_enabled = FALSE or Credit Limit Exceeded:                                              |
|         -> [Add to Khata] button is DISABLED & HIDDEN.                                             |
|         -> App alerts driver: "Credit not authorized by shopkeeper. Collect Cash or UPI QR only."  |
+----------------------------------------------------------------------------------------------------+
```

#### Khata Control Rules for Shopkeepers:
1. **Global Shop Setting**: Shopkeeper can turn Dues mode on/off for their entire store.
2. **Per-Customer Credit Whitelist**: In `business_customer_khata`, the shopkeeper specifically toggles `is_dues_enabled = TRUE` only for verified, trusted apartment residents.
3. **Custom Credit Limit**: Shopkeeper defines maximum exposure (e.g. ₹2,000 or ₹5,000). If an order causes outstanding dues to exceed the limit, the system automatically blocks credit checkout.
4. **Transparent Ledger & Repayment**: Customers view their real-time statement in the Flutter app and can settle dues anytime via UPI or counter cash payment.

---

### 11. Hyperlocal Social Meetups & Casual Dating ("Free for Coffee Tomorrow 5 PM")

To foster community connections and vibrant local socializing, the platform includes a hyperlocal casual dating and activity meetup engine:

```
[User creates Meetup via App / AI Box]
"Free for coffee tomorrow 5 PM at Blue Tokai Cafe"
                    |
                    v
[Social Meetup Post Created (social_meetups table)]
- Category: COFFEE_DATE / CASUAL_HANGOUT / SPORTS_BUDDY / WALKING_BUDDY
- Scheduled Time: Tomorrow 5:00 PM
- Geofenced Discovery: Broadcasted only to verified users within 5-10 km radius.
                    |
                    v
[Interested Nearby User sends Meetup Request]
- Sends friendly intro note via meetup_requests table.
- Creator reviews profile (photo badge, mutual interests, rating).
- Creator taps [Accept] or [Decline].
                    |
                    +--> Once ACCEPTED: Dedicated 1-on-1 chat room opens.
                    +--> Voice & Video preview powered by self-hosted LiveKit (zero phone number leakage).
```

#### Uncompromising Safety & Privacy Safeguards:
1. **Public Venues Only**: The system enforces that meetup locations must be registered public cafes, restaurants, malls, or public parks. Private residential home addresses are strictly blocked for first-time meetups.
2. **Phone Number Masking**: Users communicate exclusively through in-app SignalR chat and WebRTC audio/video calling. Real phone numbers are never revealed.
3. **Profile Verification**: Users can verify their profile with government ID and selfie checks to receive a "Verified Community Member" badge.
4. **Integrated SOS Panic Button**: During meetups, a 1-tap Emergency SOS (`sos_alerts`) is available on the screen to instantly broadcast live GPS coordinates to emergency contacts.
5. **Zero-Tolerance Anti-Harassment**: Immediate 1-tap block and report mechanisms with automated account suspension upon multiple complaints.

---

### 12. Community Classifieds & Hyperlocal Skill Bounties ("Need Teacher for 5yo child, budget ₹600/mo")

Apartment complexes and local neighborhoods frequently need trusted micro-services and skill bounties:

```
[Parent posts requirement via App / Voice AI]
"Need home tutor for my 5-year-old child (Phonics/Basic Math), budget ₹600 monthly, evening 4-5 PM"
                                   |
                                   v
[Community Classified Created (community_classifieds table)]
- Category: HOME_TUTOR / MAID_COOK / BABYSITTER / PET_CARE / APPLIANCE_REPAIR
- Target Child Age: 5 Years
- Budget: ₹600.00 (Monthly / Per-Hour / Per-Task)
- Locality: Block C, Sunshine Heights (5 km PostGIS radius)
                                   |
                                   v
[Local Tutors & Skill Providers in Society browse & submit Proposals]
- College student / certified teacher living in Tower A submits proposal:
  "I have 3 years experience teaching kindergarten phonics. Ready for ₹600/month."
                                   |
                                   v
[Parent Reviews Proposals & Confirms]
- Parent reviews teacher's verified profile, education credentials, and neighbor recommendations.
- Parent accepts proposal -> Connects directly via in-app chat and scheduled interview.
```

#### Diverse Supported Local Categories:
- **Home Tutors**: Pre-primary, nursery phonics, high school math/science, music/dance classes.
- **Domestic Helpers**: Part-time maids, morning cooks, deep cleaners.
- **Caregivers**: Babysitters, senior citizen companions, patient attendants.
- **Pet Care**: Dog walkers, pet sitters during family vacations.
- **Handyman Services**: Society electricians, plumbers, carpenter repairs.

---

### 13. High-Value Recommended Platform Expansions (Strategic Features to Add)

To transform ShopConnector into an indispensable **Hyperlocal Super-App**, we have architected 6 high-value platform expansions:

1. **Apartment / Society Gate Pass & Visitor Pre-Approval**:
   - Integration with gated society security (MyGate / Adda style).
   - When a delivery boy or cab is assigned, an auto-generated 6-digit entry code or QR pass is created.
   - Resident gets a 1-tap "Pre-Approve Entry" push notification when driver arrives at the society entrance gate.

2. **Daily Recurring Subscriptions (Doodh, Newspaper, Tiffin)**:
   - **06:00 AM – 07:30 AM Auto-Dispatch Slot**:
     - At 04:30 AM every morning, the native background worker evaluates all active `subscriptions`.
     - Checks if today's date falls within any active `subscription_pauses` (Vacation Mode).
     - For active, non-paused items, the engine groups deliveries by apartment building/tower and generates an optimized cluster delivery route for the morning vendor/rider (06:00 AM - 07:30 AM).
     - Delivery boy drops milk/newspaper at doorstep and taps [Confirm Delivered] in Flutter app -> logs into `subscription_daily_logs`.
   - **1-Tap & Voice Vacation Mode**:
     - Customer taps "Vacation Mode" in Flutter app or speaks to AI Agent:
       > *"Kal se 5 din tak milk delivery pause kar do"*
     - System creates entry in `subscription_pauses` (`pause_start_date: tomorrow, pause_end_date: tomorrow + 5 days`).
     - Daily logs for those 5 days are automatically recorded as `SKIPPED_VACATION` with ₹0.00 cost.
   - **Month-End Automated Khata Sync**:
     - On the 1st of every month at 00:05 AM, the automated billing worker calculates total consumed items:
       `Total Days = Month Days - Paused Vacation Days`.
       `e.g., 30 Days - 5 Paused Days = 25 Deliveries * ₹66 = ₹1,650`.
     - Automatically creates a transaction in `khata_transactions`:
       - `transaction_type = 'DUES_ADDED'`
       - `amount = ₹1,650.00`
       - `note = 'Monthly Milk Subscription for Sept 2026 (25 days delivered, 5 days vacation pause)'`
     - Updates `business_customer_khata.current_due_balance`.
     - Dispatches itemized WhatsApp calendar summary & SMS receipt to customer showing every single delivered vs skipped day!

3. **Hyperlocal Borrow & Lend / Tool Sharing Library**:
   - Society residents frequently need tools for short durations: *"Drill machine, ladder, car vacuum cleaner, or badminton rackets"*.
   - Residents can post borrow requests or list idle equipment for free or a nominal daily token fee with a refundable deposit.

4. **Emergency SOS & Safety Mesh (Women Safety & Midnight Travel)**:
   - Dedicated `sos_alerts` table tracking panic triggers during late-night rides or meetups.
   - **Route Deviation Alert**: If a cab deviates > 500 meters from the OSRM polyline or stops for > 5 minutes in an isolated area, the system automatically prompts safety check-in and alerts emergency contacts.

5. **Group Buying & Apartment Bulk Discounts (Community Cart)**:
   - When 5 or more neighbors in the same apartment building order seasonal items (e.g. Alphonso mangoes, fresh farm vegetables) from the same vendor, everyone receives an automatic 15% wholesale discount.
   - Vendor saves delivery costs by making a single consolidated trip to the society.

6. **Smart Voice Soundbox / Audio Receipt Announcements**:
   - Emulates Paytm / PhonePe hardware soundboxes natively on the shopkeeper's Android/iOS phone or connected Bluetooth speaker:
     *"ShopConnector par ₹1,000 prapt hue"* or *"Gupta Kirana Khata mein ₹1,000 jod diye gaye"*.

---

### 14. Real-World Operational Safeguards & Edge-Case Mitigations

To ensure the platform operates seamlessly without disputes, financial loss, or safety incidents in real-world deployment:

```
+----------------------------------------------------------------------------------------------------+
|                                OPERATIONAL EDGE-CASE DEFENSE MATRIX                                |
|                                                                                                    |
|  1. VARIABLE-PRICE VEGETABLE ORDERS                                                                |
|  - Fresh produce has dynamic daily market rates (no fixed barcodes).                               |
|  - SAFEGUARD: Shopkeeper inputs packed rates -> Interactive App/WhatsApp Price Card sent to user.  |
|  - User taps [Confirm Price & Dispatch] -> Delivery boy leaves ONLY AFTER price agreement!         |
|  - Prevents doorstep price disputes or return rejections!                                         |
|                                                                                                    |
|  2. KHATA / STORE CREDIT DEFAULT PREVENTION                                                        |
|  - SAFEGUARD: Udhar is strictly gated by shopkeeper; capped by credit_limit (e.g. ₹2,000).          |
|  - Linked to verified apartment resident profile (Flat #, Tower, RWA verification).                |
|  - Automated polite WhatsApp reminder on 1st of month with 1-tap UPI payment settlement link.      |
|                                                                                                    |
|  3. DATING & SOCIAL MEETUP SAFETY SHIELD                                                           |
|  - SAFEGUARD: Venues restricted strictly to public cafes/malls; private residential addresses      |
|    are blocked for meetups.                                                                        |
|  - Real phone numbers are masked; LiveKit WebRTC audio/video and SignalR chat only.                |
|  - Verified Community Member badge (DigiLocker / Selfie verification).                             |
|  - 1-tap Emergency SOS panic beacon broadcasts real-time GPS to emergency contacts.                |
|                                                                                                    |
|  4. MODULAR MULTI-ROLE TAB UX                                                                      |
|  - Eliminates "Super-App confusion" by partitioning into 3 clean, uncluttered tabs:                |
|    * Tab 1: Mobility & Transport (Cabs, Autos, Bike Taxi, Package Courier)                         |
|    * Tab 2: Daily Essentials (Sabjiwala Voice Ordering, Kirana, Milk Subscriptions, Khata)        |
|    * Tab 3: Society & Community (Home Tutors, Maids, Social Hangouts & Meetups)                    |
+----------------------------------------------------------------------------------------------------+
```

---

### 15. Simplified Mobile + 4-Digit PIN Auth & Driver Single-Device Order Enforcement

During development and testing, relying on external SMS OTP gateways introduces unnecessary external costs, SMS delivery delays, and telecom regulatory compliance hurdles (DLT registration in India). The platform therefore adopts a **Simplified Mobile Number + 4-Digit PIN Authentication Pipeline** with strict device audit tracking and concurrency controls:

```
+----------------------------------------------------------------------------------------------------+
|                         MOBILE + PIN AUTH & DEVICE CONCURRENCY ENGINE                              |
|                                                                                                    |
|  [User Enters Mobile: 9876543210 + 4-Digit PIN: 1234]                                              |
|                               |                                                                    |
|                               v                                                                    |
|  [POST /api/v1/auth/login-pin]                                                                     |
|  - Payload: { phone_number, pin: "1234", device_id: "hw_android_a93f", device_name: "Pixel 7" }    |
|  - Default development PIN: 1234 (Pre-hashed with BCrypt / Argon2 in users table)                  |
|  - Clean migration path: Can seamlessly toggle to SMS OTP verification via config later!           |
|                               |                                                                    |
|                               v                                                                    |
|  [DEVICE AUDIT LOGGING: user_device_sessions table]                                                |
|  - Records: { user_id, device_id, device_name, platform, ip_address, user_agent, logged_in_at }     |
|  - Provides complete audit trail of WHO logged in, WHEN, and from WHAT physical device!           |
|                               |                                                                    |
|                               v                                                                    |
|  [DRIVER CONCURRENCY CHECK: Can 2 Devices run the same Order?] -> ABSOLUTELY RESTRICTED!          |
|                               |                                                                    |
|  CASE A: Driver has an ACTIVE TASK in progress (EN_ROUTE_PICKUP, AT_PICKUP, PICKED_UP, AT_DROP)   |
|  - If Driver attempts to login on Device 2:                                                        |
|    -> HTTP 409 Conflict: "Active task #492 is in progress on Device [Pixel 7]. Cannot login or    |
|       execute order from another device until the current trip is completed or cancelled."        |
|                                                                                                    |
|  CASE B: Driver is IDLE (FREE / OFF_DUTY)                                                          |
|  - Login on Device 2 succeeds.                                                                     |
|  - Device 1 session is immediately terminated (is_active = FALSE).                                 |
|  - Device 1 JWT token is blacklisted in Redis.                                                     |
|  - SignalR pushes "ForceLogout" event to Device 1: "Logged in from another device".                |
|                                                                                                    |
|  CASE C: Telemetry & Task Event Binding (task_assignments.device_id)                                |
|  - When driver accepts an order, task_assignments binds the task to that device_id.                |
|  - Location pings or OTP submissions from any other device_id are REJECTED with 403 Forbidden!    |
+----------------------------------------------------------------------------------------------------+
```

---

## 5. Flexible Driver Compensation Engine (Formulas & Contracts)

Each shop-driver relationship supports 100% customizable compensation models:

| Contract Model | Mathematical Formula | Real-World Scenario |
| :--- | :--- | :--- |
| **`FIXED_SALARY`** | `Earning = (MonthlySalary / DaysInMonth)` | Dedicated delivery staff employed on monthly payroll. |
| **`PER_TASK`** | `Earning = PerTaskAmount` | Local grocery store paying ₹30 per completed delivery. |
| **`PER_KM`** | `Earning = DistanceKm * PerKmAmount` | Long-distance courier or cab transport (e.g. ₹10/km). |
| **`HYBRID_SALARY_TASK`** | `Earning = BaseRetainer + (TripCount * PerTaskIncentive)` | Fixed stipend + performance bonus for extra deliveries. |
| **`HYBRID_KM_TASK`** | `Earning = BaseFare + (DistanceKm * PerKmRate)` | Standard on-demand logistics (e.g. ₹20 base + ₹8/km). |
| **`DYNAMIC_SURGE`** | `Earning = CalculatedFare * SurgeMultiplier` | Rain, late night, or peak festival delivery surge. |

### Immutable Snapshotting:
When a task transitions to `COMPLETED`, the exact rate card version, distance, base amount, and calculated earning are permanently frozen in `driver_earnings`. Future changes to shop rate cards will **never** alter historical earnings!

---

## 6. Share-to-Track System (In-App & Web)

A customer can share their active ride or delivery with friends/family.

### Step-by-Step Flow:
1. **Token Generation**: Customer taps "Share Trip" -> Calls `POST /api/v1/tracking/shares` -> Generates token `tk_live_9a8f27e6c5...` valid until task completion.
2. **Dynamic Universal Link**: Produces link `https://app.shopconnector.local/track/{token}`.
3. **If receiver has the Flutter App installed**:
   - Deep link opens Flutter App -> Invokes `GET /api/v1/tracking/shares/{token}`.
   - App joins SignalR group `Tracking_Task_{taskId}`.
   - Renders live animated vehicle marker, ETA, shop name, driver first name and masked vehicle number.
   - No sensitive customer or driver private phone numbers are revealed!
4. **If receiver opens in Web Browser**:
   - React tracking page connects to SignalR via WebSockets.
   - Realtime smooth map rendering with OpenStreetMap tiles.

---

## 7. Real-Time Chat Engine (Best Architecture: SignalR + Redis + Postgres)

Instead of expensive third-party cloud SDKs (Firebase/Sendbird), the platform uses **ASP.NET Core SignalR Core with Redis Backplane**:

### Why this is the best:
- **Zero Ongoing Cloud Cost**: 100% self-hosted on your local server.
- **Ultra-Low Latency**: WebSocket binary framing (<15ms local latency).
- **Infinite Scalability**: Redis backplane handles seamless message distribution across multiple API nodes.
- **Permanent History**: Durable PostgreSQL `messages` table.
- **Offline Push Notifications**: When SignalR indicates a recipient is disconnected, background worker automatically sends an FCM push alert.

---

## 8. Broadcast Waves & Race-Condition Safe Task Acceptance

When a task requires a driver:
1. **Proximity Search**: Find available drivers where `duty_status = 'ON_DUTY'` within 5 km of `pickup_geom`.
2. **Exclusion Filter**: Exclude any driver who previously marked `REJECTED` in `task_driver_responses`.
3. **Wave Broadcast**: Top 3 nearest drivers receive a broadcast card with 30-second countdown timer and estimated trip earning.
4. **Atomic Concurrency Lock (PostgreSQL / Redis)**:
   ```csharp
   // ASP.NET Core Transactional Acceptance
   using var transaction = await _dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable);
   
   var task = await _dbContext.Tasks
       .FromSqlInterpolated($"SELECT * FROM tasks WHERE id = {taskId} FOR UPDATE")
       .FirstOrDefaultAsync();

   if (task.Status != TaskStatus.Broadcasting)
   {
       return Conflict(new { error = "TASK_ALREADY_ACCEPTED_BY_ANOTHER_DRIVER" });
   }

   task.Status = TaskStatus.Assigned;
   var assignment = new TaskAssignment { TaskId = taskId, DriverUserId = driverId, AcceptedAt = DateTime.UtcNow };
   _dbContext.TaskAssignments.Add(assignment);
   await _dbContext.SaveChangesAsync();
   await transaction.CommitAsync();

   // Notify all other broadcasted drivers that the task is taken
   await _signalRHub.Clients.Group($"Task_Wave_{taskId}").SendAsync("TaskTaken", taskId);
   ```

---

## 9. Dual OTP Verification Lifecycle & Security Matrix (Pickup & Drop)

To prevent package theft, false delivery claims, unauthorized cab rides, or laundry pickup disputes, the platform supports **Configurable Dual OTP Verification**:

```
[Driver reaches Pickup: status AT_PICKUP]
       |
       v (If is_pickup_otp_required = TRUE)
[Sender/Shop/Passenger shares 4-6 digit PICKUP OTP]
       |
[Driver submits POST /api/v1/tasks/{id}/verify-pickup-otp]
       |
       +--> OTP Valid: Task transitions to PICKED_UP (pickup_verified_at = NOW())
       |               Realtime SignalR broadcast to Customer & Shop: "Order Picked Up"
       |               Driver can now begin journey to Drop location
       |
       v
[Driver reaches Drop: status AT_DROP]
       |
       v (If is_drop_otp_required = TRUE)
[Receiver/Customer shares 4-6 digit DROP OTP]
       |
[Driver submits POST /api/v1/tasks/{id}/verify-drop-otp]
       |
       +--> OTP Valid: Task transitions to COMPLETED (drop_verified_at = NOW())
                       Triggers instant invoice generation, driver earning calculation,
                       and bidirectional rating prompt.
```

### Configurable OTP Matrix by Service Type

| Service Type | `is_pickup_otp_required` | `is_drop_otp_required` | Security Justification |
| :--- | :---: | :---: | :--- |
| **Cab / Taxi Booking** | **YES (Pickup)** | Optional / NO | Driver cannot start trip meter until the actual passenger is seated and provides Pickup OTP. |
| **E-Commerce / Food Delivery** | NO / Optional | **YES (Drop)** | Shopkeeper hands order to driver; customer gives Drop OTP upon receiving food/groceries. |
| **High-Value Courier / Electronics**| **YES (Pickup)** | **YES (Drop)** | Complete chain of custody: Sender proves handoff; receiver proves delivery. |
| **Laundry / Washing Service** | **YES (Pickup)** | **YES (Drop)** | Customer gives OTP when handing dirty clothes; gives second OTP when receiving clean clothes. |
| **Medicine / Pharmacy Delivery** | Optional | **YES (Drop)** | Ensures prescription medicines are handed directly to the intended patient. |

---

## 10. Complete API Catalog & Rate Limiting

### Rate Limiting Policies (ASP.NET Core 8 `System.Threading.RateLimiting`)

| Policy Name | Scope | Algorithm | Limit | Penalty / HTTP Status |
| :--- | :--- | :--- | :--- | :--- |
| **AuthLimiter** | IP Address | Fixed Window | 5 requests / minute | `429 Too Many Requests` |
| **ApiGeneralLimiter** | JWT User ID | Sliding Window | 120 requests / minute | `429 Too Many Requests` |
| **DispatchAcceptLimiter** | Driver User ID| Fixed Window | 10 requests / minute | `429 Too Many Requests` (Anti-bot) |
| **LocationPushLimiter**| Driver Device | Token Bucket | 1 request / second | Drops out-of-order delta packets |

### API Endpoints Reference

#### Auth & Identity
- `POST /api/v1/auth/login-pin` — Login with Mobile Number + 4-digit PIN (default `1234`). Binds `device_id` and records in `user_device_sessions`.
- `POST /api/v1/auth/request-otp` — Sends 6-digit OTP to mobile phone (Production migration).
- `POST /api/v1/auth/verify-otp` — Verifies OTP, returns JWT Access Token (15m expiry) + Refresh Token (30d expiry).
- `POST /api/v1/auth/refresh-token` — Rotates refresh token.
- `GET /api/v1/auth/devices` — Lists all active logged-in device sessions for the authenticated user.
- `DELETE /api/v1/auth/devices/{sessionId}` — Remote revoke a device session (Blacklists JWT in Redis).
- `GET /api/v1/users/me` — Fetches current user profile, memberships, active duty status.

#### Business, Catalog & Multi-Shop Driver Management
- `GET /api/v1/businesses/nearby?lat={lat}&lng={lng}&radius_km=10` — List nearby shops with active offers.
- `GET /api/v1/businesses/{id}/catalog` — Shop product catalog with live prices and stock.
- `POST /api/v1/businesses/{id}/products` — Shop owner adds/modifies product price/stock.
- `POST /api/v1/businesses/{id}/drivers` — Shop adds driver by mobile phone & sets contract (Salary, Per Task, Per Km).
- `GET /api/v1/businesses/{id}/drivers` — Shop views its own driver roster (Zero-Knowledge of driver's other shops).

#### Orders & Tasks
- `POST /api/v1/orders` — Customer places order with idempotent header `Idempotency-Key`.
- `POST /api/v1/tasks/delivery` — Creates delivery task for an order.
- `POST /api/v1/tasks/cab` — Creates passenger cab booking.
- `GET /api/v1/tasks/{id}` — Fetches complete task details, originating shop name, stops, driver info.

#### Driver Operations, Vehicles & Dispatch
- `GET /api/v1/drivers/vehicles` — List all registered vehicles in driver's garage.
- `POST /api/v1/drivers/vehicles` — Register a new vehicle (type: BIKE/CAB/AUTO, plate number, brand/model).
- `DELETE /api/v1/drivers/vehicles/{id}` — Remove a vehicle from driver's garage.
- `POST /api/v1/drivers/duty` — Toggle duty state (`ON_DUTY` requires `{ vehicle_id }`, `OFF_DUTY`, `BUSY`).
- `POST /api/v1/drivers/network-toggle` — Toggles "Connect with Open Network" (`is_network_enabled = true/false`) to receive open customer broadcasts.
- `GET /api/v1/drivers/preferences/radius` — Get driver's configured pickup and delivery radius limits.
- `PUT /api/v1/drivers/preferences/radius` — Set pickup radius (`max_pickup_radius_km`) and delivery radius (`max_delivery_radius_km`).
- `GET /api/v1/drivers/nearby-available?lat={lat}&lng={lng}&radius_km=3` — Live stream of nearby online riders for Customer Home map.
- `GET /api/v1/drivers/broadcasts` — Active incoming dispatch requests for the driver (shows originating shop name).
- `POST /api/v1/tasks/{id}/accept` — Driver accepts task (Acquires atomic database lock).
- `POST /api/v1/tasks/{id}/reject` — Driver rejects task with optional reason (Never broadcasted again).
- `POST /api/v1/tasks/{id}/verify-pickup-otp` — Driver verifies pickup OTP provided by sender/shopkeeper (Transitions task: `AT_PICKUP` -> `PICKED_UP`).
- `POST /api/v1/tasks/{id}/verify-drop-otp` — Driver verifies drop OTP provided by receiver/customer (Transitions task: `AT_DROP` -> `COMPLETED`).
- `POST /api/v1/tasks/{id}/resend-otp?type=PICKUP|DROP` — Resends OTP to sender or receiver via SMS/Push.

#### Tracking, Offline Batch Sync & Sharing
- `GET /api/v1/tracking/{taskId}/live` — Retrieves current vehicle coordinate and OSRM route.
- `POST /api/v1/tracking/batch-sync` — Flushes buffered offline GPS points in batches from mobile SQLite into DB.
- `POST /api/v1/tracking/shares` — Creates a secure shareable tracking token.
- `GET /api/v1/tracking/shares/{token}` — Resolves share token for in-app or web live tracking.
- `DELETE /api/v1/tracking/shares/{id}` — Revokes active tracking token.

#### Chat & Audio/Video Calling
- `GET /api/v1/conversations/{taskId}` — Gets or creates task chat room.
- `GET /api/v1/conversations/{id}/messages?page=1` — Retrieves chat history.
- `POST /api/v1/calls/token` — Issues short-lived LiveKit WebRTC room token for authorized call.

#### Inter-City Trip Banners & AI Booking (Jaipur -> Delhi, etc.)
- `POST /api/v1/trip-offers` — Driver creates an inter-city route banner (Origin, Destination, Departure Time, Price, Seats).
- `GET /api/v1/trip-offers/active?origin={city}&destination={city}` — Customers discover active inter-city banners.
- `POST /api/v1/trip-offers/{id}/book` — Customer books one or more seats on an inter-city banner trip.
- `DELETE /api/v1/trip-offers/{id}` — Driver cancels an active trip offer banner.

#### Comprehensive Logs & Audit Trail (Who Did What & Every Message Sent)
- `GET /api/v1/audit/logs?entity_type={type}&entity_id={id}&page=1` — Audit trail tracking who did what, when, and from what device/IP.
- `GET /api/v1/communication/logs?recipient={identifier}&channel={sms|whatsapp|email|push}&page=1` — Complete delivery log of every SMS, WhatsApp message, email, and push notification sent.

#### Digital Khata & Store Credit Ledger
- `GET /api/v1/businesses/{id}/khata` — Shopkeeper views list of all customer credit/dues accounts.
- `GET /api/v1/businesses/{id}/khata/{customerId}` — Shopkeeper or Customer views specific ledger balance & history.
- `PUT /api/v1/businesses/{id}/khata/{customerId}/toggle` — Shopkeeper toggles `is_dues_enabled` (ON/OFF) and sets custom `credit_limit`.
- `POST /api/v1/businesses/{id}/khata/transactions` — Records credit purchase or cash/UPI debt settlement repayment.

#### Hyperlocal Social Meetups & Casual Dating
- `POST /api/v1/social/meetups` — User creates public meetup (Coffee Date, Sports Buddy, Hangout).
- `GET /api/v1/social/meetups/nearby?lat={lat}&lng={lng}&radius_km=10` — Discovers active meetups nearby.
- `POST /api/v1/social/meetups/{id}/request` — Sends join request with introductory message.
- `PUT /api/v1/social/meetups/requests/{requestId}` — Creator accepts or declines meetup request.

#### Community Classifieds & Local Skill Bounties
- `POST /api/v1/classifieds` — Post requirement (e.g. Home tutor for 5yo child, budget ₹600/month).
- `GET /api/v1/classifieds/nearby?lat={lat}&lng={lng}&category={category}` — Search local tasks within radius.
- `POST /api/v1/classifieds/{id}/proposals` — Tutors/service providers submit quotes and proposals.
- `PUT /api/v1/classifieds/proposals/{proposalId}/accept` — Poster accepts proposal and hires provider.

#### Daily Recurring Subscriptions & Vacation Mode
- `POST /api/v1/subscriptions` — Creates daily milk/newspaper/tiffin subscription (06:00 AM - 07:30 AM slot).
- `GET /api/v1/subscriptions/me` — Customer views active recurring deliveries.
- `POST /api/v1/subscriptions/{id}/pause` — 1-Tap Vacation mode: pauses deliveries for date range (`pause_start_date`, `pause_end_date`).
- `DELETE /api/v1/subscriptions/{id}/pause/{pauseId}` — Resumes subscription early before vacation end date.
- `GET /api/v1/subscriptions/{id}/calendar?month={month}&year={year}` — Interactive monthly calendar showing delivered days, skipped days, and vacation pause days.
- `POST /api/v1/subscriptions/billing/month-end-sync` — Background billing worker endpoint to aggregate delivered items, subtract vacation days, and push consolidated invoice to `khata_transactions` with `DUES_ADDED`.
- `DELETE /api/v1/subscriptions/{id}` — Cancels recurring subscription.

#### Emergency Safety & SOS
- `POST /api/v1/safety/sos` — Triggers panic beacon with live GPS coordinate; alerts emergency contacts.
- `PUT /api/v1/safety/sos/{id}/resolve` — Resolves active emergency alert.

#### Multi-Shop Quotations & RFQs (Rate Discovery & Direct Order)
- `POST /api/v1/rfqs` — Creates new RFQ (Mode: Single Shop, 3 Selected Shops, or Open Network Broadcast).
- `GET /api/v1/rfqs/{id}` — Fetches RFQ status, parsed items list, and all submitted vendor quotes.
- `POST /api/v1/rfqs/{id}/quotes` — Vendor submits itemized price quotation with ETA.
- `POST /api/v1/rfqs/{id}/accept-quote` — Customer accepts preferred vendor quote (Converts to order & initiates dispatch).
- `DELETE /api/v1/rfqs/{id}` — Cancels active RFQ.

---

## 11. Flutter Mobile App UX & Design Architecture

The mobile experience is built as **one unified Flutter app** using `flutter_bloc` / `riverpod`. 

```
+--------------------------------------------------------------------------------+
|                             UNIFIED FLUTTER APP                                |
|                                                                                |
|  [Dynamic Context Switcher Drawer]                                             |
|  - Switch between: Customer Mode | Driver Mode | Shopkeeper Mode | Parent Mode |
|                                                                                |
|  MODE 1: CUSTOMER VIEW                                                         |
|  - Modern search bar, categorical carousel (Grocery, Meds, Cab, Services).     |
|  - Realtime bottom sheet: Live ride/delivery card with live map & driver ETA.  |
|  - Quick-action buttons: [Share Trip to WhatsApp] [Call Driver] [Chat].        |
|                                                                                |
|  MODE 2: DRIVER OPERATIONAL VIEW                                               |
|  - Sleek top bar: [Go Online (ON_DUTY)] toggle switch.                         |
|  - Radar Wave Card: Slide to Accept / Tap to Reject with countdown timer.     |
|  - In-app turn-by-turn navigation with smooth car marker heading alignment.   |
|  - Realtime earnings dashboard & daily trip summary.                          |
|                                                                                |
|  MODE 3: SHOPKEEPER VIEW                                                       |
|  - Order Kanban Board (New Orders -> Preparing -> Out for Delivery -> Done).   |
|  - Quick stock toggle (In Stock / Out of Stock with 1 tap).                    |
|                                                                                |
|  MODE 4: SCHOOL PARENT VIEW                                                    |
|  - Student bus tracker with automatic "Bus Approaching Stop" alert.            |
+--------------------------------------------------------------------------------+
```

---

## 12. Python AI Agent Microservice & Pluggable Grok Integration (`ai-agent/`)

The platform includes a **standalone Python microservice** (`ai-agent/`) running on FastAPI and native Python 3.14 (Port 8000) that powers voice/text interaction across all three platform personas:
- **Customer Assistant**: Natural language grocery/food ordering ("1 kg chini aur 2 packet bread bhejo"), ride requests, "Mera order/cab kahan tak pahuncha?" (with real-time landmark and ETA).
- **Shopkeeper Assistant**: Voice inventory management ("Amul doodh out of stock kar do"), daily order summaries, revenue reports.
- **Delivery Driver Assistant**: Turn-by-turn guidance, daily earnings breakdown, hands-free voice assistance.

### 12.1 Pluggable LLM Provider Pattern (Grok by Default)

The AI Agent integrates with **Grok (xAI API)** via an abstracted `LLMProvider` interface, allowing instant switching to Gemini, Claude, or local Ollama models simply by updating `.env` (`LLM_PROVIDER=grok`):

```python
# ai-agent/app/providers/base.py
class LLMProvider(ABC):
    @abstractmethod
    async def chat_completion(self, messages, tools=None, temperature=0.3):
        pass

# ai-agent/app/providers/grok_provider.py
class GrokProvider(LLMProvider):
    def __init__(self, api_key: str, model: str = "grok-2"):
        self.api_key = api_key
        self.model = model
        self.base_url = "https://api.x.ai/v1"
```

### 12.2 Deterministic Tool Calling Engine
The agent does not hallucinate facts. It calls authenticated REST endpoints on the ASP.NET Core API:
- `get_task_status_and_eta(task_id)`: Fetches live driver position, current street name, and remaining minutes.
- `update_product_stock(business_id, product_sku, is_available)`: Modifies shop stock in real time.
- `get_driver_daily_earnings(driver_id)`: Summarizes total completed trips, base pay, and tips.
- `create_order_draft(customer_id, items)`: Builds structured cart for human confirmation.
- `process_customer_grocery_intent(raw_text, mode, target_shop_ids)`: Classifies prompt into `RATE_INQUIRY` vs `DIRECT_ORDER`, extracts bilingual items, and routes RFQ or creates cart.

### 12.3 Strict Guardrails
- **Read queries are instant**; all write/financial actions (placing orders, spending money, assigning drivers) **MUST require explicit human confirmation**.
- Coordinates are never exposed directly; the agent converts raw GPS points into conversational landmarks (e.g., *"Driver Fraser Road par hai aur 3 minute mein pahuchega"*).

---

## 13. GitHub Repository Structure, Source Control & Upload Plan

All platform code, microservices, mobile apps, database migrations, and documentation are targeted for upload and version control in the official repository:
- **Remote GitHub URL**: `https://github.com/prem78niit/shop_connector`

### 13.1 Monorepo Clean Directory Layout

```
shop_connector/
├── .github/
│   └── workflows/
│       ├── dotnet-build.yml       # Continuous Integration for .NET 8 API
│       ├── python-tests.yml       # Pytest & linting for ai-agent
│       └── flutter-analyze.yml    # Flutter static analysis
├── .agents/                       # Antigravity agent skills & workflows
│   └── skills/
│       └── unified-mobility-platform/
├── ai-agent/                      # Standalone Python 3.14 Microservice (FastAPI + Grok)
│   ├── app/
│   │   ├── main.py
│   │   ├── providers/             # Pluggable Grok / Gemini / Claude providers
│   │   ├── tools/                 # Deterministic tool calling
│   │   └── prompts/
│   ├── requirements.txt
│   └── .env.example
├── src/                           # Backend ASP.NET Core 8 Web API
│   ├── ShopConnector.Api/         # Controllers, SignalR Hubs, Rate Limiters
│   ├── ShopConnector.Core/        # Domain Entities, Interfaces, Enums
│   ├── ShopConnector.Infrastructure/ # EF Core (shopconnector_core & telemetry), Mosquitto, Redis
│   └── ShopConnector.sln
├── mobile/                        # Flutter Mobile App (Unified Multi-Role)
│   ├── lib/
│   │   ├── features/              # customer, driver, shopkeeper, school
│   │   ├── core/telemetry/        # Smooth movement, Kalman filter, offline SQLite buffer
│   │   └── main.dart
│   └── pubspec.yaml
├── dashboard/                     # React 18 / Vite Web Dashboard
│   ├── src/
│   ├── package.json
│   └── vite.config.ts
├── docs/                          # Comprehensive Architectural Blueprints
│   ├── WORKFLOW.md                # Master Production Architecture
│   ├── DATABASE.md                # Complete DDL Schemas & Relationships
│   └── AI_AGENT.md                # Python AI Microservice Runbook
├── .gitignore                     # Windows native, .NET, Python, Node, Flutter ignores
└── README.md                      # Quickstart runbook for local host Windows setup
```

### 13.2 Git Initialization & Remote Push Commands

To upload and synchronize all local development files with the GitHub repository:

```powershell
# 1. Initialize Git in the project root
git init

# 2. Add the remote GitHub origin
git remote add origin https://github.com/prem78niit/shop_connector.git

# 3. Create and switch to default 'main' branch
git branch -M main

# 4. Stage all architectural documents, skills, and codebases
git add .

# 5. Commit with conventional commit format
git commit -m "feat: complete master production architecture, 22 DDL schemas, Grok AI agent, and multi-tenant workflows"

# 6. Push to remote GitHub repository
git push -u origin main
```

---

## 14. Verification & Master Implementation Checklist

All user requirements and architectural pillars are completely aligned:
- **100% Native Windows — NO DOCKER**: Direct local execution of Postgres 18, Mosquitto MQTT, Redis, LiveKit native binary, .NET 8, Python 3.14, React, and Flutter.
- **Decoupled Two-Database Architecture**: Primary operational relational DB (`shopconnector_core`) separated from high-volume time-series GPS DB (`shopconnector_telemetry`).
- **Smooth Cab Tracking**: Flutter Kalman filter + Tween LatLng lerp + Shortest delta angle rotation + OSRM road snap.
- **Dual OTP Verification**: Configurable pickup and drop OTPs across tasks.
- **Standalone Python AI Agent**: Multi-role assistant powered by pluggable Grok LLM with deterministic tool calling.
- **Apartment Voice Grocery AI**: Natural language parsing of Hindi/Hinglish grocery lists into structured items.
- **3 Customer Request Modes**: Single Shop Direct, 3-Shop Selective Rate Quotes, and Open Network Hyperlocal Broadcast.
- **AI Intent Decision Engine**: Distinguishes between `RATE_INQUIRY` (quotes comparison) and `DIRECT_ORDER` (immediate cart checkout).
- **Digital Khata Ledger & Gated Dues**: Shopkeeper master toggle, per-customer credit limit whitelist, and doorstep payment collection.
- **Hyperlocal Dating & Casual Meetups**: Public cafe venue verification, phone masking, and emergency SOS panic triggers.
- **Community Classifieds**: Hyperlocal hiring bounties (tutors, maids, cooks) with spatial radius matching.
- **GitHub Monorepo Upload**: Structured for continuous integration and push to `https://github.com/prem78niit/shop_connector`.

We are ready to start scaffold generation or building out Phase 1 modules!
