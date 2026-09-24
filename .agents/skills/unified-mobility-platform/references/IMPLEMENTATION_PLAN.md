# Recommended Implementation Order

## Step 1
Repository structure, environment configuration, Docker Compose for:
- PostgreSQL
- Redis
- Mosquitto
- API
- background worker

## Step 2
Identity + OTP + User + Roles + Business + Membership

## Step 3
Customer + Address + Shop + Category + Product + Availability + Offer

## Step 4
Task engine + state machine + events

## Step 5
Driver profile + duty + assignment + broadcast + reject rules

## Step 6
MQTT + Mosquitto + Redis latest location + tracking consumer

## Step 7
Live map + customer tracking + shop tracking + history

## Step 8
Chat + push notifications + LiveKit calls

## Step 9
Order + invoice + rating + driver earning

## Step 10
Shopping quote flow + service/video request

## Step 11
School routes + stops + students + parent + bus trip + geofence alerts

## Step 12
AI orchestrator and tool calling

## Step 13
Hardening:
- tests
- load tests
- security
- observability
- migrations
- backups
- deployment

## First vertical-slice acceptance test

A test user:
1. registers
2. creates shop
3. adds product
4. creates customer order
5. creates delivery task
6. driver goes ON_DUTY
7. driver receives broadcast
8. driver rejects another task and never receives it again
9. driver accepts this task
10. driver publishes GPS over MQTT
11. Redis updates current location
12. customer sees live location
13. shop sees live location
14. customer and driver chat
15. customer and driver call via LiveKit
16. driver reaches pickup
17. driver reaches drop
18. customer verifies OTP
19. task completes
20. notification sent
21. customer rates driver
22. driver rates customer
23. shop rates driver
24. driver earning is calculated
25. tracking history is stored
26. invoice can be generated
27. audit trail exists

Only after this passes should the team expand into the remaining task types.
