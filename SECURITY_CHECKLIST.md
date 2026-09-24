# Security and Privacy Checklist

## Authentication
- OTP brute-force protection
- refresh-token rotation
- session/device revocation
- suspicious login controls

## Authorization
Test every endpoint for:
- user A accessing user B
- business A accessing business B
- parent accessing unrelated child
- driver accessing unrelated task
- shop staff exceeding role
- customer accessing another customer's tracking

## Location privacy
- only expose location when task relationship allows it
- approximate location for public tracking where possible
- do not expose home address unnecessarily
- configurable history retention
- audit sensitive location access

## Media
- private object storage
- signed URLs
- expiration
- content-type validation
- max file size
- malware scanning where available

## MQTT
- TLS
- unique credentials/certificates
- ACL
- topic authorization
- no anonymous publish
- rate limits

## LiveKit
- backend-issued short-lived tokens
- room access authorization
- task/relationship authorization
- no API secrets in clients

## Financial
- server-side price calculation
- immutable transaction snapshots
- idempotent payment operations
- audit adjustments
