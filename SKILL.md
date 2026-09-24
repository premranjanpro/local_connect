# Unified Mobility & Local Services Platform — Development Skill

## 0. Purpose

Build one multi-role, multi-business platform where the same user account can act as:
- Customer/Guest
- Shop Owner / Shop Staff
- Delivery Boy / Driver
- School Transport Admin
- Parent
- Service Provider (plumber, electrician, mechanic, washer, etc.)

The system must not create separate identities/apps for every role. Identity is centralized; capabilities and business memberships determine what the user can see and do.

Primary clients:
- React web dashboard
- Flutter mobile app using the same application experience for customer, shop, driver, and service provider
- Public/customer tracking pages can work from a secure web link without forcing app installation

Core backend:
- ASP.NET Core Web API (recommended)
- PostgreSQL
- Redis for hot/live state
- MQTT with Mosquitto for high-frequency tracking/telemetry
- LiveKit for real-time audio/video calling and optionally realtime communication
- WebSocket/SignalR or equivalent for application realtime events
- Object storage for images/video/documents
- Background workers for notifications, dispatch, ETA, billing, AI processing

Routing/location:
- OpenStreetMap data
- OSRM for routing/distance/duration/ETA
- Geofencing engine
- GPS tracking with configurable intervals

AI:
- AI-assisted request understanding
- Voice/text-to-structured-task
- Video/image understanding for service requests
- Product/order assistance
- AI-generated useful structured content from customer requests
- AI must never silently commit money, accept a quote, or assign a provider without explicit user confirmation.

---

# 1. Non-negotiable architecture rules

1. ONE User identity.
2. A user can belong to multiple businesses.
3. A business can have multiple users with different permissions.
4. A user can own/manage multiple shops.
5. A user can be both customer and shop owner.
6. A driver can work for multiple shops.
7. A driver can also be a customer and can add/manage a shop if permitted.
8. Never hard-code one user = one role.
9. Never hard-code one driver = one shop.
10. Never hard-code one task = one driver until assignment is accepted.
11. Every operational request becomes a Task.
12. Orders, cab bookings, washing pickup/drop, medicine delivery, generic pickup/drop, shopping-on-demand, plumber requests, etc. are task/business variants.
13. Tracking is a common platform capability, not a delivery-only feature.
14. Current location and historical location are separate data paths.
15. MQTT is for telemetry/transport, not the source of truth for business state.
16. PostgreSQL is the durable source of truth.
17. Redis stores current/hot state and ephemeral dispatch data.
18. All important state transitions must produce durable domain events/audit records.
19. Every important event must be notification-capable.
20. Financial amounts must use decimal/numeric, never floating point.
21. Historical prices/rates must be snapshotted at the time of transaction.
22. Permissions must be scoped by business/organization/resource.
23. A rejected task must not be rebroadcast to the same driver for that task.
24. If a driver rejects a customer globally, future tasks from that customer should be filtered for that driver according to the configured relationship.
25. Duty/online state and assignment state are different concepts.
26. AI suggestions require human confirmation for irreversible actions.
27. Do not expose another user's phone number, exact home address, or private location unnecessarily.
28. Do not store raw GPS forever by default; use configurable retention policies.
29. APIs must be idempotent where retries can create duplicate orders, assignments, payments, or events.
30. Never put business rules only in the Flutter/React client.

---

# 2. Product model

## 2.1 Business types

Support at least:
- Medical shop
- Grocery shop
- Restaurant/food
- General retail
- Laundry/washing
- Courier/delivery
- Cab operator
- School/transport
- Service provider
- Independent driver
- Future arbitrary local business

A Business has:
- Business profile
- Owners
- Staff
- Roles/permissions
- Branches
- Products/services
- Price lists
- Offers
- Availability
- Customers
- Delivery/driver relationships
- Invoices
- Reports

## 2.2 User model

A user may have:
- Customer profile
- Driver profile
- Provider profile
- Business memberships
- Parent/student relationships
- Addresses
- Vehicles
- Ratings
- Wallet/settlement profile

Do not use a single `UserType` column as the entire authorization model. A coarse user type may exist for UI defaults, but permissions come from roles/capabilities and active context.

---

# 3. Dynamic dashboard / active context

The same Flutter app is one application.

Default behavior:
- Logged-in user opens Customer dashboard.
- If user has an active shop context, they can switch to Shop dashboard.
- If user has Driver capability and is ON_DUTY, show Driver dashboard as the active operational mode.
- If driver goes OFF_DUTY, customer dashboard remains available.
- User can switch business context if they have permission.
- The backend must authorize every request independently; UI switching is not security.

Example:

Ravi:
- Customer
- Driver
- Shop owner of Shop A
- Delivery staff of Shop B

UI:
`Profile -> My Roles / My Businesses`
- Customer
- Driver
- Shop A
- Shop B

Driver state:
- OFF DUTY -> customer-first home
- ON DUTY -> driver operational dashboard
- ONLINE/AVAILABLE -> can receive broadcast tasks
- BUSY -> receives no new incompatible assignments
- OFFLINE -> no realtime dispatch

---

# 4. Business membership and permissions

Core relationship:

`User -> BusinessMembership -> Business`

Membership fields:
- BusinessId
- UserId
- RoleId
- BranchId (nullable)
- Status
- EffectiveFrom
- EffectiveTo
- CreatedBy
- CreatedAt

Examples:
- User 10 -> Shop 1 -> Owner
- User 11 -> Shop 1 -> Manager
- User 12 -> Shop 1 -> Billing
- User 13 -> Shop 1 -> Delivery
- User 13 -> Shop 2 -> Delivery
- User 14 -> Shop 2 -> Owner

Permission examples:
- business.view
- business.edit
- product.create
- product.update
- product.price
- product.offer
- order.view
- order.create
- order.assign
- delivery.dispatch
- invoice.create
- invoice.cancel
- reports.view
- driver.manage
- customer.view
- tracking.view
- tracking.history
- staff.manage

---

# 5. Product catalog

A shopkeeper can later add products.

Hierarchy:
- Category
- SubCategory
- Brand (optional)
- Product
- ProductVariant
- SKU

Example:
- Medicine
  - Fever
  - Pain
  - Cold & Cough
- Grocery
  - Staples
  - Beverages
- Electronics
  - Mobile
  - Accessories

Product fields:
- Name
- Description
- CategoryId
- SubCategoryId
- BrandId
- SKU
- Unit
- Tax
- BasePrice
- SellingPrice
- MRP
- CostPrice (restricted)
- Stock
- IsAvailable
- IsActive
- Images
- Attributes
- Search keywords

Do not duplicate the same product category hierarchy for every shop. Use a global category taxonomy, while allowing business-specific mappings.

A shop can:
- Add existing catalog product
- Create private product
- Set own price
- Set availability
- Set stock
- Set offer
- Set minimum order quantity
- Set delivery eligibility

---

# 6. Offers and availability

Support:
- Available/unavailable
- Stock quantity
- Time-based availability
- Branch-specific availability
- Offer price
- Discount percentage
- Buy X Get Y (future)
- Coupon (future)
- Offer start/end
- Customer eligibility
- Maximum quantity

Important:
`Product master price != Shop selling price != Order snapshot price`

When an order is created, copy the actual price/discount/tax into OrderItemSnapshot.

Never recalculate old invoices using today's product price.

---

# 7. Task engine — central architecture

Every actionable request creates a Task.

Task types:
- DELIVERY
- PICKUP
- PICKUP_AND_DROP
- CAB_BOOKING
- MEDICINE_DELIVERY
- SHOPPING_REQUEST
- WASHING_PICKUP
- WASHING_DROP
- SERVICE_REQUEST
- PLUMBER
- ELECTRICIAN
- COURIER
- SCHOOL_PICKUP
- SCHOOL_DROP
- GENERIC

Task lifecycle:
`DRAFT -> REQUESTED -> BROADCASTING -> OFFERED -> ACCEPTED -> ASSIGNED -> EN_ROUTE_TO_PICKUP -> AT_PICKUP -> PICKED_UP -> EN_ROUTE_TO_DROP -> AT_DROP -> COMPLETED`

Alternative paths:
- CANCELLED
- EXPIRED
- REJECTED
- FAILED
- NO_SHOW
- DISPUTED

Not every task uses every state. Define allowed transitions per TaskType.

Every transition:
1. Validate permissions
2. Validate current state
3. Update transactionally
4. Write TaskEvent
5. Publish realtime event
6. Queue notifications
7. Write audit record where appropriate

---

# 8. Customer demand / quote marketplace

Example:
Customer says:
`Mujhe 1 kg chini chahiye.`

Customer creates a Shopping Request:
- Item: Sugar
- Quantity: 1 kg
- Pickup/source area
- Delivery address
- Max/target price optional
- Notes
- Photos/video optional

Nearby eligible delivery boys/providers are broadcast.

Driver sees:
`1 KG SUGAR | Customer area | Deliver to ...`

Driver can submit quote:
`₹80`

Customer sees:
`Ravi offered ₹80`

Customer:
- Accept
- Reject
- Ask another quote
- Cancel

Only after explicit acceptance:
- Quote becomes accepted
- Task assignment is created
- Driver can proceed

Quote table must preserve:
- OfferedAmount
- Currency
- ValidUntil
- DriverId
- TaskId
- Status
- CustomerResponseAt

No automatic acceptance.

---

# 9. Service request via video/image/voice

Customer can submit:
- Text
- Voice
- Image
- Video

Example:
`Customer uploads video and says: "Mujhe plumber ka kaam karana hai."`

Pipeline:
1. Store media securely.
2. Create ServiceRequest.
3. AI analyzes media/text.
4. AI generates structured request:
   - category = plumbing
   - suspected work
   - location
   - urgency
   - visible parts/materials
   - questions needed
5. Customer reviews AI interpretation.
6. Customer confirms.
7. Broadcast to eligible plumbers/providers.
8. Provider quotes price.
9. Customer accepts quote.
10. Task starts.
11. Tracking + chat + call + rating + invoice.

AI must label uncertain fields as uncertain.

---

# 10. Nearby broadcast / dispatch

When a customer requests a task:
1. Determine service type.
2. Determine pickup/service location.
3. Query nearby eligible drivers/providers.
4. Filter:
   - ON_DUTY
   - ONLINE
   - correct capability/service
   - business permissions
   - vehicle capacity if relevant
   - not blocked by customer
   - not rejected this task
   - not already incompatible/busy
5. Rank candidates by configurable rules:
   - distance/ETA
   - availability
   - workload
   - service skill
   - business relationship
6. Broadcast in waves.

Do not broadcast to every driver in the whole city.

Use geospatial indexes / Redis GEO / PostGIS if enabled.

### Rejection rules

`TaskDriverResponse`:
- INTERESTED
- ACCEPTED
- REJECTED
- EXPIRED
- NO_RESPONSE

If driver rejects Task 123:
- Do not send Task 123 again to that driver.

If driver selects `NOT_INTERESTED_IN_THIS_CUSTOMER`:
- Store customer-driver block/preference.
- Future tasks from that customer are filtered for that driver until relationship is changed.

Keep task rejection and customer relationship preference as two separate concepts.

---

# 11. Driver duty state

Driver state:
- OFF_DUTY
- ON_DUTY
- ONLINE_AVAILABLE
- BUSY
- PAUSED
- OFFLINE
- SUSPENDED

`ON_DUTY` means willing to work.
`ONLINE_AVAILABLE` means eligible to receive dispatch.
`BUSY` means currently assigned/incompatible for new tasks.

Never infer duty only from GPS.

---

# 12. Multiple tasks per delivery boy

A driver can receive:
- One pickup
- One drop
- Multiple pickups
- Multiple drops
- Pickup + drop chains
- Multiple orders from multiple shops

Create:
`Task`
`TaskAssignment`
`TaskStop`

A route can contain:
1. Shop A pickup
2. Customer A drop
3. Shop B pickup
4. Customer B drop

Do not assume one driver = one task.

For future route optimization, create a `JourneyPlan` with ordered stops.

---

# 13. Tracking architecture

### Live path

Flutter driver app:
`GPS -> MQTT -> Mosquitto -> Tracking Consumer -> Redis`

Redis stores:
- latest lat/lng
- timestamp
- speed
- heading
- accuracy
- battery (optional)
- online state
- device/network state

### Durable path

Tracking consumer asynchronously writes selected/batched points to PostgreSQL:
`LocationHistory`

Use configurable sampling:
- live update: e.g. 3–10 sec
- history storage: e.g. 15–60 sec or event-based
- configurable by policy/task/business

Do not write every MQTT message synchronously to PostgreSQL.

### MQTT topics

Use authenticated tenant-scoped topics, for example:
`tracking/v1/{tenantId}/driver/{driverId}/location`

Never allow a client to publish another driver's topic.

Use QoS appropriately and retained messages only where justified.

Mosquitto must use:
- TLS
- username/password or certificates
- ACLs
- per-device/client identity
- rate limits
- max payload
- topic restrictions

---

# 14. Current location vs history

`LatestLocation`:
- one current record per tracked subject
- optimized for reads

`LocationHistory`:
- append-oriented
- partition by time if needed
- retention policy
- never used as the primary live query path

`TrackingSession` / `Journey`:
- groups location history into an operational trip.

---

# 15. ETA and routing

OSRM should be behind a RoutingService abstraction.

Inputs:
- origin
- destination
- intermediate stops
- profile
- optional avoid/constraints

Outputs:
- route geometry
- distance
- duration
- legs
- steps (if required)

ETA:
- current driver location
- next task stop
- OSRM route
- optional traffic provider later

Do not expose OSRM internals to mobile clients. API returns a stable platform DTO.

---

# 16. Geofencing

Geofence types:
- CUSTOMER_STOP
- SHOP
- SCHOOL
- BUS_STOP
- PICKUP
- DROP
- SERVICE_LOCATION

Events:
- ENTER
- EXIT
- DWELL
- APPROACHING

Geofence engine:
`Location -> Candidate Geofences -> Distance/Polygon Check -> Event -> Rule -> Notification`

Prevent duplicate alerts with an idempotency/event key.

---

# 17. School transport module

Entities:
- School
- SchoolBranch
- Student
- ParentGuardian
- Bus
- Driver
- Attendant
- Route
- RouteVersion
- RouteStop
- StudentRouteAssignment
- BusTrip
- TripStop
- StudentTrip
- StudentPickupDropEvent

Flow:
`School -> Route -> Stops -> Students`

Trip:
`BusTrip -> Driver/Bus -> Journey -> Stops -> Student statuses`

Parent:
- sees only linked child information
- can see assigned bus
- next stop
- ETA
- bus approach
- pickup/drop status
- trip history if permitted

Notifications:
- trip started
- bus approaching
- bus arrived
- child picked up
- child dropped
- route deviation (if configured)
- emergency event

Route versions are immutable after use by a trip. Create a new version when route changes.

---

# 18. Cab booking

CabBooking can create one or more Tasks:
- pickup
- passenger trip
- drop

Fields:
- passenger
- pickup
- drop
- vehicle category
- scheduled time
- fare quote
- driver
- OTP
- trip status

Reuse:
- driver duty
- dispatch
- journey
- tracking
- ETA
- LiveKit call
- chat
- rating

---

# 19. Washing pickup/drop

Laundry/washing flow:
`Customer Request -> Pickup Task -> Washing Order -> Drop Task`

Can have:
- item count
- weight
- service type
- pickup quote
- final amount
- before/after photos
- status
- payment
- invoice

---

# 20. Medicine / local delivery

Shop creates order:
- customer
- products
- quantities
- price snapshots
- address
- delivery task

Assignment:
- shop's own driver
- shared driver
- broadcast driver
- manually assigned driver

Customer can track driver after tracking permission begins.

---

# 21. Chat

Need platform conversation model, not a separate chat implementation per module.

Entities:
- Conversation
- ConversationParticipant
- Message
- MessageAttachment
- MessageRead
- MessageReaction (optional)

Conversation types:
- CUSTOMER_DRIVER
- CUSTOMER_SHOP
- SHOP_DRIVER
- CUSTOMER_PROVIDER
- SUPPORT
- GROUP_TASK

Every message must include:
- conversation id
- sender
- timestamp
- message type
- body
- attachments
- task/order reference optionally

Authorization:
- participant must be authorized for the referenced business/task.

Realtime:
- WebSocket/SignalR for text delivery/read state
- Push notification when offline

Do not use MQTT as the primary user chat transport.

---

# 22. LiveKit calls

LiveKit is for realtime audio/video calls.

Call types:
- Customer <-> Driver
- Customer <-> Shop
- Shop <-> Driver
- Customer <-> Service Provider
- Support

Call flow:
1. User requests call.
2. Backend authorizes participants.
3. Backend creates/returns short-lived LiveKit token.
4. Client joins room.
5. Backend records call metadata:
   - CallSession
   - participants
   - start/end
   - duration
   - task reference
   - status

Never generate LiveKit tokens solely in the client.

Never expose API secrets in Flutter/React.

Call recordings, if ever enabled, require explicit policy/consent and secure storage.

---

# 23. Notifications

Create a central NotificationService.

Channels:
- In-app
- Push
- SMS
- WhatsApp (future/integration)
- Email (optional)

Important events:
- task requested
- broadcast sent
- driver interested
- driver accepted
- driver rejected
- assignment
- driver approaching
- arrived
- pickup
- drop
- cancellation
- quote received
- quote accepted/rejected
- payment
- invoice
- school bus approaching
- child picked/dropped
- call missed
- new chat
- offer published
- product unavailable

Use:
`NotificationTemplate`
`NotificationPreference`
`NotificationDelivery`
`NotificationEvent`

Make notifications idempotent.

---

# 24. Ratings

Rating is task-context based.

After completed task:
- Customer rates driver/provider
- Driver can rate customer
- Customer can rate shop
- Shop can rate driver
- Parent can rate transport service if configured

Use:
`Rating`
- TaskId
- FromUserId
- ToUserId
- BusinessId nullable
- Score
- Comment
- Tags
- CreatedAt

One allowed rating per defined relationship/event unless correction workflow exists.

Do not allow ratings to alter financial records retroactively.

---

# 25. Invoices and financial architecture

Shop owner can create invoice.

Separate:
- Order subtotal
- Discount
- Tax
- Delivery charge
- Service charge
- Grand total
- Payment status

Driver earnings are separate:
- salary
- per-order
- per-km
- fixed + variable
- rate card
- bonus
- adjustment

Never derive driver earning from customer delivery charge by assumption.

Create:
- RateCard
- RateCardVersion
- DriverBusinessContract
- DriverEarning
- Settlement
- Invoice
- InvoiceItem
- Payment
- PaymentTransaction

At transaction time snapshot the rate/version.

---

# 26. Driver compensation models

Per business relationship, support:
- FIXED_SALARY
- PER_ORDER
- PER_KM
- FIXED_PLUS_PER_ORDER
- FIXED_PLUS_PER_KM
- RATE_CARD
- CUSTOM

Example:
Ravi:
- Shop A = ₹20/order
- Shop B = ₹8/km
- Shop C = ₹12,000 salary

This belongs to `BusinessDriverRelationship` / contract, not globally to the user.

---

# 27. Shop owner adding another shop

User profile:
`My Businesses -> Add Business`

Flow:
1. Create Business draft.
2. Verify owner.
3. Add address/contact.
4. Select category.
5. Add branch.
6. Configure staff.
7. Add products.
8. Configure delivery rules.
9. Publish.

Same user can manage many businesses.

---

# 28. Product discovery

Customer:
- nearby shops
- categories
- search
- product
- price
- availability
- offer
- estimated delivery
- shop rating

A customer can see offers from multiple shops.

Example:
`1kg Sugar`
- Shop A ₹52 available
- Shop B ₹49 available
- Shop C unavailable

Do not make the platform the seller unless business rules explicitly say so.

---

# 29. Customer -> shop connection

The initial cold-start strategy:
- Shop can create order for existing customer.
- Customer receives a secure tracking link.
- Customer can track in browser without installing the app.
- Repeated customer can install the app for:
  - order history
  - reorder
  - saved addresses
  - multiple shops
  - offers
  - live tracking
  - support/chat/call

Shop becomes the initial customer acquisition channel.

---

# 30. AI architecture

AI should sit behind a controlled `AI Orchestrator`.

Examples:
Customer says:
`Mujhe ek kg chini chahiye`

AI extracts:
```json
{
  "intent": "SHOPPING_REQUEST",
  "items": [{"name": "sugar", "quantity": 1, "unit": "kg"}],
  "delivery_required": true
}
```

Customer says:
`Mujhe plumber ka kaam karana hai`

AI:
- identifies service intent
- asks missing questions
- can inspect image/video if enabled
- generates structured request
- asks customer to confirm

AI can generate useful content:
- task title
- structured description
- item list
- customer instructions
- summary for provider
- notification copy
- invoice draft description

AI must not:
- fabricate a quote
- accept a quote without confirmation
- change price silently
- expose private data
- assign itself as a provider
- execute financial actions without authorization

---

# 31. Core PostgreSQL tables

Minimum foundation:

## Identity
- users
- user_profiles
- roles
- permissions
- role_permissions
- user_roles

## Business
- businesses
- business_branches
- business_memberships
- business_driver_relationships
- business_settings

## Catalog
- categories
- subcategories
- brands
- products
- product_variants
- business_products
- product_prices
- offers
- inventory

## Customer
- customer_profiles
- addresses
- customer_business_relationships

## Tasks
- tasks
- task_types
- task_assignments
- task_stops
- task_events
- task_driver_responses
- quotes

## Mobility
- vehicles
- driver_profiles
- driver_duty_sessions
- journeys
- journey_stops
- latest_locations
- location_history
- geofences
- geofence_events
- tracking_policies

## Orders
- orders
- order_items
- order_item_snapshots
- order_status_history

## School
- schools
- students
- parent_guardians
- student_guardians
- buses
- school_routes
- route_versions
- route_stops
- student_route_assignments
- bus_trips
- trip_stops
- student_trips
- student_trip_events

## Communication
- conversations
- conversation_participants
- messages
- message_attachments
- call_sessions
- call_participants

## Notifications
- notification_templates
- notification_preferences
- notifications
- notification_deliveries

## Financial
- invoices
- invoice_items
- payments
- payment_transactions
- rate_cards
- rate_card_versions
- driver_earnings
- settlements

## Ratings
- ratings

## AI
- ai_requests
- ai_outputs
- ai_confirmations
- ai_media_analysis

## Audit
- audit_logs

---

# 32. API design

Use versioned APIs:
`/api/v1/...`

Suggested modules:
- /auth
- /users
- /businesses
- /memberships
- /catalog
- /products
- /offers
- /customers
- /orders
- /tasks
- /dispatch
- /drivers
- /tracking
- /routing
- /geofences
- /journeys
- /school
- /chat
- /calls
- /notifications
- /ratings
- /invoices
- /payments
- /earnings
- /ai

Use DTOs, validation, pagination, filtering, sorting and consistent error responses.

---

# 33. Security

Required:
- JWT access token + refresh token
- short-lived access tokens
- secure refresh rotation
- OTP login with rate limiting
- device/session management
- role + resource authorization
- tenant/business scoping
- object-level authorization
- signed media URLs
- encrypted secrets
- HTTPS/TLS
- MQTT TLS + ACL
- LiveKit token authorization
- audit logs
- rate limiting
- idempotency keys
- anti-replay for critical operations
- input validation
- file type/size validation
- malware scanning for uploaded files where available

Never trust:
- userId sent by client
- businessId sent by client
- driverId sent by client
- price sent by client
- role sent by client
- tracking ownership sent by client

Derive/validate these from authenticated context and server-side relationships.

---

# 34. Observability

Every production component needs:
- structured logs
- correlationId
- requestId
- userId
- businessId
- taskId/orderId where applicable
- metrics
- health checks
- error tracking

Metrics:
- MQTT messages/sec
- GPS processing latency
- Redis latency
- task broadcast count
- assignment latency
- notification success rate
- LiveKit call failures
- API latency
- failed payments
- queue depth

---

# 35. Offline-first driver behavior

Driver app must tolerate:
- weak network
- GPS unavailable
- app backgrounding
- temporary MQTT disconnect

Queue local operational events:
- duty state
- task status
- pickup/drop confirmation
- proof upload

When reconnected:
- synchronize with idempotency keys
- resolve server state
- never duplicate an event

GPS:
- keep a local buffer
- upload/broadcast after reconnect
- mark stale location correctly

---

# 36. Flutter requirements

One app.

Screens should be capability/context based:
- Splash
- Login/OTP
- Customer Home
- Search
- Product/Shop
- Cart
- Order
- Live Tracking
- Chat
- Call
- Profile
- My Businesses
- Shop Dashboard
- Products
- Offers
- Orders
- Delivery Team
- Driver Dashboard
- Duty toggle
- Task inbox
- Task detail
- Route/Journey
- Earnings
- School dashboard
- Parent dashboard
- Notifications
- Ratings
- Invoice
- Settings

Do not create four copies of the same application logic.

Use a modular feature structure.

---

# 37. React dashboard requirements

React is for:
- Shop management
- Admin
- School administration
- Business reports
- Product/catalog management
- Orders
- Driver management
- Route management
- Tracking map
- Invoices
- Settlements
- Permissions

React and Flutter must consume the same API contracts.

---

# 38. Realtime event contract

Use a common event envelope:

```json
{
  "eventId": "uuid",
  "eventType": "TASK_DRIVER_ASSIGNED",
  "occurredAt": "2026-09-24T12:00:00Z",
  "taskId": "uuid",
  "businessId": "uuid",
  "actorUserId": "uuid",
  "payload": {}
}
```

Events must be versioned if contract changes.

---

# 39. MVP phases

## Phase 1 — Foundation
- Auth/OTP
- User
- Business
- Membership/permissions
- Customer
- Driver
- Shop
- Product/category
- Basic Order
- Task engine
- Assignment
- Driver duty
- MQTT tracking
- Redis current location
- PostgreSQL history
- Basic push notifications
- Basic chat
- Basic LiveKit call
- Rating

## Phase 2 — Delivery marketplace
- Nearby driver broadcast
- Driver reject/accept rules
- Multiple tasks
- Quotes
- Customer shopping requests
- Delivery pricing
- Driver earnings
- Invoice
- Offers
- Product availability
- Customer tracking links

## Phase 3 — Services
- Video/voice customer requests
- Plumber/electrician/etc.
- Provider quotes
- AI request structuring
- Media analysis
- Advanced dispatch

## Phase 4 — School
- School
- Routes
- Route versions
- Stops
- Students
- Parents
- Bus trips
- Geofence
- ETA alerts
- Pickup/drop events
- Parent tracking

## Phase 5 — Scale
- advanced route optimization
- multi-branch
- advanced settlement
- analytics
- WhatsApp
- payment gateway
- stronger AI agent/tool calling
- horizontal scaling

---

# 40. Definition of Done

A feature is not done until:
- API implemented
- DB migration created
- authorization tested
- validation tested
- audit/event generated
- realtime event handled if applicable
- notification handled if applicable
- Flutter flow implemented
- React flow implemented if applicable
- loading/error/offline states handled
- duplicate request tested
- unauthorized access tested
- relevant indexes added
- logs/metrics added
- unit/integration tests added
- documentation updated

---

# 41. Agent behavior / coding instructions

When an AI coding agent receives a requirement:

1. Inspect existing repository before changing code.
2. Do not rewrite working modules unnecessarily.
3. Identify impacted domain modules.
4. Produce a short implementation plan.
5. Check database migration impact.
6. Check API contract impact.
7. Check Flutter/React impact.
8. Check realtime/event impact.
9. Check authorization impact.
10. Implement in small verifiable steps.
11. Run tests/build/lint.
12. Report changed files and migrations.
13. Never invent an existing API/table.
14. Never silently change business rules.
15. Never hard-code IDs, prices, driver IDs, business IDs or role IDs.
16. Preserve backward compatibility where possible.
17. Use feature flags for risky new behavior.
18. Keep domain logic in backend services, not UI.
19. Use transactions for state transitions and financial operations.
20. Use idempotency for commands that can be retried.
21. Treat external services as replaceable adapters.

---

# 42. First implementation target

Do NOT start by implementing every module.

First prove this vertical slice end-to-end:

`Customer -> Shop -> Order -> Task -> Driver broadcast -> Driver accepts -> MQTT GPS -> Redis -> API realtime -> Customer live map -> Shop live map -> Chat -> LiveKit call -> Delivery OTP -> Complete -> Rating -> Driver earning -> Notification -> History`

Once this slice is stable, reuse the same Task/Journey/Tracking infrastructure for:
- cab
- washing
- medicine
- generic pickup/drop
- shopping quote
- service request
- school bus

This vertical slice is the architectural proof of the entire platform.
