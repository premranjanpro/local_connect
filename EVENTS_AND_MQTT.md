# Realtime, MQTT, Mosquitto and Event Contract

## Separation of responsibilities

MQTT:
- driver/bus telemetry
- device status
- high-frequency location

Redis:
- latest location
- driver availability
- nearby driver sets
- short-lived dispatch locks
- rate limiting/cache

PostgreSQL:
- durable business state
- orders
- tasks
- assignments
- events
- ratings
- invoices
- history

WebSocket/SignalR:
- application realtime events to React/Flutter

LiveKit:
- audio/video calls

Push:
- offline notifications

## Example MQTT topic

`tracking/v1/{businessScope}/{subjectType}/{subjectId}/location`

Payload:

```json
{
  "deviceId": "uuid",
  "lat": 25.5941,
  "lng": 85.1376,
  "accuracy": 8.5,
  "speed": 6.2,
  "heading": 90,
  "timestamp": "2026-09-24T16:00:00Z",
  "sequence": 12345
}
```

Server validates:
- authenticated device
- subject ownership
- allowed topic
- sequence/replay
- timestamp drift
- payload bounds

## Domain event examples

TASK_CREATED
TASK_BROADCAST_STARTED
TASK_OFFER_RECEIVED
TASK_DRIVER_REJECTED
TASK_DRIVER_ACCEPTED
TASK_ASSIGNED
DRIVER_ON_DUTY
DRIVER_AVAILABLE
DRIVER_BUSY
JOURNEY_STARTED
LOCATION_UPDATED
DRIVER_NEAR_PICKUP
ARRIVED_PICKUP
PICKUP_COMPLETED
DRIVER_NEAR_DROP
ARRIVED_DROP
TASK_COMPLETED
TASK_CANCELLED
QUOTE_CREATED
QUOTE_ACCEPTED
PRODUCT_AVAILABLE
PRODUCT_UNAVAILABLE
OFFER_PUBLISHED
BUS_TRIP_STARTED
BUS_APPROACHING_STOP
BUS_ARRIVED_STOP
STUDENT_PICKED
STUDENT_DROPPED
INVOICE_CREATED
PAYMENT_COMPLETED
RATING_CREATED
CALL_STARTED
CALL_ENDED
MESSAGE_CREATED

## Idempotency

Every command that can be retried should accept:
`Idempotency-Key`

Store result against the key and authenticated actor/context.

Events must have unique IDs.

## Broadcast algorithm

1. Task created.
2. Determine pickup/service point.
3. Query nearby eligible drivers.
4. Remove:
   - off-duty
   - offline
   - busy
   - unsupported service
   - rejected task
   - customer-blocked
5. Create dispatch wave.
6. Notify drivers.
7. First valid acceptance wins using transactional lock.
8. Other offers become EXPIRED/NOT_SELECTED.
9. Create TaskAssignment.
10. Notify customer/shop.
11. Start tracking session when configured.

Do not use a naive "first client response" without server transaction/locking.
