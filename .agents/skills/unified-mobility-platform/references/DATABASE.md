# PostgreSQL Data Model — Core Blueprint

## Conventions
- UUID primary keys
- `created_at`, `updated_at` UTC
- soft delete where business data requires it
- `numeric(12,2)` or appropriate precision for money
- timestamptz for time
- PostGIS recommended for geo queries
- unique constraints on business-scoped identifiers
- partial indexes for active/current records

## Core relationships

User
  -> BusinessMembership -> Business
  -> DriverProfile
  -> CustomerProfile
  -> ParentGuardian
  -> ProviderProfile

Business
  -> Branch
  -> BusinessMembership
  -> BusinessProduct
  -> Orders
  -> DriverBusinessRelationship

Order
  -> OrderItems
  -> Task
  -> Invoice
  -> Payment

Task
  -> TaskAssignments
  -> TaskStops
  -> TaskEvents
  -> Quotes
  -> Journey

Journey
  -> LatestLocation
  -> LocationHistory
  -> GeofenceEvents

## Important tables

### users
id, phone_number, pin_hash, email, full_name, avatar_url, status, created_at, updated_at

### businesses
id, name, business_type, owner_user_id, phone, email, address_text, latitude, longitude, geom, is_active, created_at, updated_at

### vehicles
id, driver_user_id, vehicle_type, brand_model, plate_number, color, is_verified, is_active, created_at

### driver_profiles
user_id, license_number, duty_status, active_vehicle_id, is_network_enabled, max_pickup_radius_km, max_delivery_radius_km, is_verified, rating_avg, total_trips, updated_at

### business_memberships
id, business_id, user_id, role_id, branch_id, status, effective_from, effective_to

### business_driver_relationships
id, business_id, driver_user_id, contract_type, salary_monthly, per_task_amount, per_km_amount, base_fare, surge_bonus_multiplier, is_active, created_at, updated_at

### categories
id, parent_id, name, slug, active

### products
id, category_id, subcategory_id, name, description, unit, active

### business_products
id, business_id, product_id, sku, selling_price, mrp, tax_rate, stock_qty, is_available, active

### offers
id, business_product_id, offer_type, value, starts_at, ends_at, active

### customers
id, user_id, default_address_id

### addresses
id, user_id, label, address_text, latitude, longitude, geom, active

### orders
id, business_id, customer_user_id, status, subtotal, discount, tax, delivery_charge, total, currency, created_at

### order_items
id, order_id, business_product_id, product_name_snapshot, quantity, unit_price_snapshot, tax_snapshot, discount_snapshot, line_total

### tasks
id, task_type, source_type, source_id, customer_user_id, status, priority, requested_at, scheduled_at, pickup_address_id, drop_address_id, pickup_otp, is_pickup_otp_required, pickup_verified_at, drop_otp, is_drop_otp_required, drop_verified_at

### task_assignments
id, task_id, driver_user_id, vehicle_id, device_id, assignment_status, assigned_at, accepted_at, started_at, completed_at

### task_driver_responses
id, task_id, driver_user_id, response, reason, created_at, unique(task_id, driver_user_id)

### quotes
id, task_id, provider_user_id, amount, currency, message, expires_at, status, created_at

### task_events
id, task_id, event_type, actor_user_id, latitude, longitude, metadata_json, occurred_at, unique(event_id)

### journeys
id, task_id, driver_user_id, vehicle_id, status, started_at, ended_at

### latest_locations
subject_type, subject_id, latitude, longitude, accuracy, speed, heading, recorded_at, online_state
Primary key: subject_type + subject_id

### location_history
id, journey_id, subject_type, subject_id, latitude, longitude, accuracy, speed, heading, recorded_at, geom
Partition by month when scale requires it.

### geofences
id, business_id, type, entity_id, center/geom, radius_m, active

### geofence_events
id, geofence_id, journey_id, event_type, recorded_at, idempotency_key unique

### driver_duty_sessions
id, driver_user_id, status, started_at, ended_at, device_id

### conversations
id, conversation_type, task_id, business_id, created_at

### conversation_participants
conversation_id, user_id, joined_at, left_at

### messages
id, conversation_id, sender_user_id, message_type, body, created_at

### call_sessions
id, task_id, initiated_by, livekit_room_name, status, started_at, ended_at, duration_seconds

### ratings
id, task_id, from_user_id, to_user_id, business_id, score, comment, created_at

### invoices
id, business_id, customer_user_id, order_id, invoice_number, subtotal, tax, discount, total, status

### invoice_items
id, invoice_id, description, quantity, unit_price, tax_rate, line_total

### driver_earnings
id, task_id, driver_user_id, business_id, calculation_type, rate_version_id, base_amount, variable_amount, bonus, adjustment, total, status

### settlements
id, driver_user_id, business_id, period_start, period_end, gross, adjustments, payable, status, paid_at

### notifications
id, recipient_user_id, event_type, title, body, task_id, status, created_at

### audit_logs
id, actor_user_id, role, entity_type, entity_id, action, ip_address, user_agent, old_state_json, new_state_json, metadata_json, created_at

### communication_logs
id, channel, recipient_identifier, recipient_user_id, related_task_id, template_code, subject, message_body, provider_name, provider_message_id, delivery_status, failure_reason, sent_at, delivered_at

### driver_trip_offers
id, driver_user_id, vehicle_id, origin_city, destination_city, origin_lat, origin_lng, destination_lat, destination_lng, departure_time, price_per_seat, total_seats, available_seats, description, status, ai_prompt_original, created_at, expires_at

### business_customer_khata
id, business_id, customer_user_id, is_dues_enabled, credit_limit, current_due_balance, notes, created_at, updated_at, unique(business_id, customer_user_id)

### khata_transactions
id, khata_id, order_id, transaction_type, amount, payment_mode, balance_after, recorded_by_user_id, note, created_at

### social_meetups
id, creator_user_id, meetup_type, title, description, preferred_gender, min_age, max_age, meetup_venue_name, latitude, longitude, geom, scheduled_at, status, created_at, expires_at

### meetup_requests
id, meetup_id, requester_user_id, intro_message, status, responded_at, created_at, unique(meetup_id, requester_user_id)

### community_classifieds
id, requester_user_id, category, title, description, target_child_age, budget_amount, budget_frequency, preferred_timing, location_text, latitude, longitude, geom, status, created_at

### classified_proposals
id, classified_id, provider_user_id, proposed_rate, proposal_message, status, created_at, unique(classified_id, provider_user_id)

### subscriptions
id, business_id, customer_user_id, product_id, quantity, frequency, delivery_time_slot, status, start_date, end_date, created_at

### subscription_pauses
id, subscription_id, pause_start_date, pause_end_date, reason, created_at

### subscription_daily_logs
id, subscription_id, delivery_date, quantity, unit_price, total_price, status, driver_user_id, delivered_at, billed_to_khata, khata_transaction_id, created_at, unique(subscription_id, delivery_date)

### sos_alerts
id, user_id, task_id, meetup_id, latitude, longitude, geom, alert_type, status, triggered_at, resolved_at

### customer_rfqs
id, customer_user_id, rfq_mode, target_business_ids, raw_prompt, items_json, delivery_address_id, radius_km, ai_detected_intent, status, winning_business_id, converted_order_id, created_at, expires_at

### rfq_business_quotes
id, rfq_id, business_id, itemized_rates_json, total_price, estimated_delivery_minutes, notes, status, created_at, unique(rfq_id, business_id)

### user_device_sessions
id, user_id, device_id, device_name, platform, ip_address, user_agent, fcm_token, jwt_jti, is_active, logged_in_at, last_active_at, revoked_at

## Index priorities
- business_memberships(user_id, business_id)
- business_driver_relationships(business_id, driver_user_id, status)
- orders(business_id, created_at desc)
- orders(customer_user_id, created_at desc)
- tasks(status, requested_at)
- task_assignments(driver_user_id, assignment_status)
- task_driver_responses(task_id, driver_user_id) unique
- latest_locations(subject_type, subject_id)
- location_history(journey_id, recorded_at)
- notifications(recipient_user_id, created_at desc)
- messages(conversation_id, created_at)
- business_products(business_id, is_available, active)
- offers(starts_at, ends_at, active)

Use PostGIS GiST indexes for geo queries.
