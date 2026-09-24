# UX and End-to-End Flows

## Customer

Home:
- Search
- Nearby shops
- Categories
- Offers
- Active tasks
- Recent orders
- Request service
- Request delivery
- Book cab

Order:
Shop -> Product -> Cart -> Address -> Delivery option -> Confirm

Tracking:
- driver/provider name
- approximate location
- ETA
- task status
- chat
- call
- cancel where permitted

## Shop

Dashboard:
- Today's orders
- Pending
- Preparing
- Out for delivery
- Completed
- Drivers
- Sales
- Offers

Order:
- accept
- prepare
- assign driver
- track driver
- call/chat
- invoice
- complete

Catalog:
- category
- product
- price
- availability
- offer
- stock

Team:
- add user
- role
- branch
- delivery permission

## Driver

OFF DUTY:
- customer dashboard remains accessible

ON DUTY:
- driver dashboard
- availability toggle
- incoming tasks
- active journey
- map
- task sequence
- earnings

Incoming broadcast:
- task type
- approximate pickup
- approximate drop
- quote/payment
- countdown
- accept/reject
- reject reason

Active task:
- navigate
- call
- chat
- arrived
- pickup proof
- start delivery
- OTP
- complete

## School Admin

- buses
- drivers
- routes
- route versions
- stops
- students
- guardians
- assign students
- start/monitor trips
- live map
- alerts
- history

## Parent

- child list
- assigned route
- bus
- next stop
- ETA
- approaching alert
- pickup/drop status
- trip history

## Public tracking

No-install web page:
- secure short-lived token
- task status
- approximate driver location
- ETA
- shop name
- support
- no unnecessary PII

Token must be revocable and scoped to one task/customer view.
