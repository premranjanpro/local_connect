"""
tool_engine.py — Deterministic Tool Calling Engine for ShopConnector AI Agent

Implements all 7 tools that call the .NET API with real HTTP requests:
  1. parse_grocery_voice_order       — structure voice item list
  2. process_customer_grocery_intent — classify + submit order / RFQ
  3. pause_subscription              — 1-tap vacation mode
  4. record_khata_transaction        — log store credit or repayment
  5. create_driver_trip_banner       — post intercity route banner
  6. post_social_meetup              — casual hangout / coffee date post
  7. post_community_classified       — skill/job bounty (tutor, maid, cook)

All tools that mutate state require a confirmed JWT bearer token.
Human confirmation is required for financial actions (khata record).
"""

import os
import re
import httpx
from typing import Any, Dict, List, Optional
from datetime import date, timedelta
from .models import GroceryItem
from .intent_parser import parse_items_from_text

# Base URL of the .NET API — read from env or config
API_BASE = os.environ.get("SHOPCONNECTOR_API_URL", "http://localhost:5000")

# ── Shared HTTP client (keep-alive pooling) ──────────────────────────────────

_client: Optional[httpx.AsyncClient] = None

def get_http_client() -> httpx.AsyncClient:
    global _client
    if _client is None or _client.is_closed:
        _client = httpx.AsyncClient(
            base_url=API_BASE,
            timeout=10.0,
            headers={"Content-Type": "application/json"}
        )
    return _client


def _auth_headers(token: str) -> Dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ═══════════════════════════════════════════════════════════════════════════════
#  TOOL 1 — parse_grocery_voice_order
# ═══════════════════════════════════════════════════════════════════════════════

def parse_grocery_voice_order(raw_text: str) -> Dict[str, Any]:
    """
    Parses spoken/typed grocery requests (Hindi / Hinglish / English)
    into a structured JSON list of line items with quantity and unit.

    Example input:  "5kg aaloo, 2 kg pyaz, 1 kg tamatar, 500g paneer"
    Returns structured JSON ready to submit as an order.
    """
    items: List[GroceryItem] = parse_items_from_text(raw_text)

    if not items:
        return {
            "success": False,
            "message": "Koi item parse nahi ho saka. Please list like: '5kg aaloo, 2kg pyaz, 1kg tamatar' format mein likhein.",
            "items": []
        }

    subtotal_note = f"{len(items)} item(s) parsed"

    return {
        "success": True,
        "message": f"✅ {subtotal_note}. Order ready hai.",
        "items": [item.model_dump() for item in items],
        "raw_text": raw_text
    }


# ═══════════════════════════════════════════════════════════════════════════════
#  TOOL 2 — process_customer_grocery_intent
# ═══════════════════════════════════════════════════════════════════════════════

async def process_customer_grocery_intent(
    raw_text: str,
    user_token: str,
    business_id: Optional[str],
    intent_type: str = "DIRECT_ORDER",
    target_mode: str = "SINGLE_SHOP"
) -> Dict[str, Any]:
    """
    Submits a grocery order or RFQ to the .NET API.

    - DIRECT_ORDER  → POST /api/v1/tasks  (creates task)
    - RATE_INQUIRY  → POST /api/v1/customer-rfq  (requests quotes from shops)
    """
    items = parse_items_from_text(raw_text)
    if not items:
        return {"success": False, "message": "Order mein koi item nahi mila. Phir se try karein."}

    client = get_http_client()
    headers = _auth_headers(user_token)

    if intent_type == "RATE_INQUIRY":
        # POST /api/v1/customer-rfq
        body = {
            "itemsText": raw_text,
            "requestMode": target_mode,
            "businessIds": [business_id] if business_id else [],
            "items": [item.model_dump() for item in items]
        }
        try:
            resp = await client.post("/api/v1/customer-rfq", json=body, headers=headers)
            if resp.status_code in (200, 201):
                data = resp.json()
                return {
                    "success": True,
                    "message": f"✅ Rate inquiry bhej di gayi hai {len(items)} items ke liye. Shops se quotes aane pe notification milega.",
                    "rfq_id": data.get("id"),
                    "mode": target_mode
                }
            else:
                return {"success": False, "message": f"RFQ submit fail: {resp.text}", "status": resp.status_code}
        except Exception as e:
            return {"success": False, "message": f"API connection error: {str(e)}"}

    else:
        # DIRECT_ORDER → Create a task
        items_json = ", ".join([f"{i.quantity}{i.unit} {i.normalized_name}" for i in items])
        body = {
            "taskType": "GroceryDelivery",
            "pickupAddress": "Shop Location",
            "pickupLatitude": 26.9124,
            "pickupLongitude": 75.7873,
            "dropoffAddress": "Customer Location",
            "dropoffLatitude": 26.9180,
            "dropoffLongitude": 75.7995,
            "paymentMode": "Cash",
            "businessId": business_id,
            "orderItems": items_json
        }
        try:
            resp = await client.post("/api/v1/tasks", json=body, headers=headers)
            if resp.status_code in (200, 201):
                data = resp.json()
                return {
                    "success": True,
                    "message": f"✅ Order place ho gaya! Driver assign hone par notification milega. Items: {items_json}",
                    "task_id": data.get("id"),
                    "status": data.get("status")
                }
            else:
                return {"success": False, "message": f"Order submit fail: {resp.text}", "status": resp.status_code}
        except Exception as e:
            return {"success": False, "message": f"API connection error: {str(e)}"}


# ═══════════════════════════════════════════════════════════════════════════════
#  TOOL 3 — pause_subscription
# ═══════════════════════════════════════════════════════════════════════════════

async def pause_subscription(
    subscription_id: str,
    pause_days: int,
    user_token: str,
    reason: str = "Vacation Mode"
) -> Dict[str, Any]:
    """
    Pauses a daily subscription for `pause_days` starting from tomorrow.
    Calls: POST /api/v1/subscriptions/{id}/pause

    Human confirmation required before calling if amount impact > ₹100.
    """
    start_date = (date.today() + timedelta(days=1)).isoformat()
    end_date = (date.today() + timedelta(days=pause_days)).isoformat()

    client = get_http_client()
    headers = _auth_headers(user_token)

    body = {
        "pauseStartDate": start_date,
        "pauseEndDate": end_date,
        "reason": reason
    }

    try:
        resp = await client.post(
            f"/api/v1/subscriptions/{subscription_id}/pause",
            json=body,
            headers=headers
        )
        if resp.status_code in (200, 201):
            return {
                "success": True,
                "message": f"✅ Delivery {start_date} se {end_date} tak ({pause_days} din) pause kar di gayi hai. In dinon ka ₹0 charge rahega.",
                "pause_start": start_date,
                "pause_end": end_date
            }
        else:
            return {"success": False, "message": f"Pause fail: {resp.text}", "status": resp.status_code}
    except Exception as e:
        return {"success": False, "message": f"API connection error: {str(e)}"}


# ═══════════════════════════════════════════════════════════════════════════════
#  TOOL 4 — record_khata_transaction  [⚠ FINANCIAL — REQUIRES HUMAN CONFIRMATION]
# ═══════════════════════════════════════════════════════════════════════════════

async def record_khata_transaction(
    business_id: str,
    customer_id: str,
    amount: float,
    entry_type: str,   # "DuesDebit" or "PaymentReceived"
    notes: str,
    user_token: str,
    confirmed: bool = False
) -> Dict[str, Any]:
    """
    ⚠ FINANCIAL ACTION — Records a Khata (Udhar) debit or payment.
    Calls: POST /api/v1/khata/transactions

    confirmed=True must be explicitly set by the caller AFTER the user
    has verbally confirmed the amount on screen (guardrail enforcement).
    """
    if not confirmed:
        return {
            "success": False,
            "requires_confirmation": True,
            "message": (
                f"⚠️ Confirmation Required: Aap ₹{amount:.2f} ka {entry_type} record karna chahte hain "
                f"({notes}). Confirm karne ke liye 'Haan' ya 'Confirm' bolein."
            ),
            "amount": amount,
            "entry_type": entry_type
        }

    client = get_http_client()
    headers = _auth_headers(user_token)

    body = {
        "businessId": business_id,
        "customerId": customer_id,
        "amount": amount,
        "entryType": entry_type,
        "notes": notes
    }

    try:
        resp = await client.post("/api/v1/khata/transactions", json=body, headers=headers)
        if resp.status_code in (200, 201):
            verb = "Debit" if entry_type == "DuesDebit" else "Payment received"
            return {
                "success": True,
                "message": f"✅ Khata updated: {verb} ₹{amount:.2f} — {notes}",
                "transaction": resp.json()
            }
        else:
            return {"success": False, "message": f"Khata transaction fail: {resp.text}"}
    except Exception as e:
        return {"success": False, "message": f"API connection error: {str(e)}"}


# ═══════════════════════════════════════════════════════════════════════════════
#  TOOL 5 — create_driver_trip_banner
# ═══════════════════════════════════════════════════════════════════════════════

async def create_driver_trip_banner(
    origin: str,
    destination: str,
    departure_time: str,
    fare_amount: float,
    available_seats: int,
    user_token: str
) -> Dict[str, Any]:
    """
    Creates an intercity trip banner for a driver.
    Calls: POST /api/v1/drivers/trip-banners

    Triggered when driver says: "Jaipur se Delhi kal 11 baje 1500 mein jaaunga"
    """
    client = get_http_client()
    headers = _auth_headers(user_token)

    body = {
        "origin": origin,
        "destination": destination,
        "departureTime": departure_time,
        "farePerSeat": fare_amount,
        "availableSeats": available_seats
    }

    try:
        resp = await client.post("/api/v1/drivers/trip-banners", json=body, headers=headers)
        if resp.status_code in (200, 201):
            data = resp.json()
            return {
                "success": True,
                "message": (
                    f"✅ Trip banner live ho gaya! {origin} → {destination} | "
                    f"{departure_time} | ₹{fare_amount:.0f}/seat | {available_seats} seats. "
                    f"Nearby customers ko push notification bhej di gayi hai."
                ),
                "banner_id": data.get("id")
            }
        else:
            return {"success": False, "message": f"Banner create fail: {resp.text}"}
    except Exception as e:
        return {"success": False, "message": f"API connection error: {str(e)}"}


# ═══════════════════════════════════════════════════════════════════════════════
#  TOOL 6 — post_social_meetup
# ═══════════════════════════════════════════════════════════════════════════════

async def post_social_meetup(
    category: str,
    proposed_time: str,
    venue_preference: str,
    max_radius_km: int,
    user_token: str,
    description: str = ""
) -> Dict[str, Any]:
    """
    Posts a casual social meetup or coffee date to the community feed.
    Calls: POST /api/v1/social/meetups

    Safety: Venue must be a verified public place (cafe, mall).
    Phone numbers are always masked. LiveKit calling used for audio.
    """
    client = get_http_client()
    headers = _auth_headers(user_token)

    body = {
        "category": category,
        "proposedTime": proposed_time,
        "venuePreference": venue_preference,
        "maxRadiusKm": max_radius_km,
        "description": description or f"Casual {category} meetup at {venue_preference}. Feel free to connect!",
        "isPublicVenueOnly": True
    }

    try:
        resp = await client.post("/api/v1/social/meetups", json=body, headers=headers)
        if resp.status_code in (200, 201):
            data = resp.json()
            return {
                "success": True,
                "message": (
                    f"✅ Meetup post live ho gayi! Category: {category} | Time: {proposed_time} | "
                    f"Venue: {venue_preference}. Nearby log aapki post dekh sakte hain. "
                    f"Phone number masked hai — interested log LiveKit call karenge."
                ),
                "meetup_id": data.get("id")
            }
        else:
            return {"success": False, "message": f"Meetup post fail: {resp.text}"}
    except Exception as e:
        return {"success": False, "message": f"API connection error: {str(e)}"}


# ═══════════════════════════════════════════════════════════════════════════════
#  TOOL 7 — post_community_classified
# ═══════════════════════════════════════════════════════════════════════════════

async def post_community_classified(
    role_needed: str,
    description: str,
    budget_monthly: float,
    radius_km: int,
    user_token: str,
    child_age: Optional[int] = None,
    schedule: str = "Flexible"
) -> Dict[str, Any]:
    """
    Posts a hyperlocal skill bounty or job classified.
    Calls: POST /api/v1/social/classifieds

    Examples: Home tutor, maid, cook, babysitter, carpenter.
    Spatially matched within radius_km to nearby colony residents.
    """
    client = get_http_client()
    headers = _auth_headers(user_token)

    full_description = description
    if child_age:
        full_description = f"[{child_age} year old child] " + description

    body = {
        "roleNeeded": role_needed,
        "description": full_description,
        "budgetMonthly": budget_monthly,
        "radiusKm": radius_km,
        "schedule": schedule,
        "category": "Education" if "tutor" in role_needed.lower() or "teacher" in role_needed.lower() else "Home Services"
    }

    try:
        resp = await client.post("/api/v1/social/classifieds", json=body, headers=headers)
        if resp.status_code in (200, 201):
            data = resp.json()
            return {
                "success": True,
                "message": (
                    f"✅ Classified post live! {role_needed} required | Budget: ₹{budget_monthly:.0f}/month | "
                    f"{radius_km}km radius mein sab ko notify kiya gaya hai. "
                    f"Interested candidates app mein proposal bhejenge."
                ),
                "classified_id": data.get("id")
            }
        else:
            return {"success": False, "message": f"Classified post fail: {resp.text}"}
    except Exception as e:
        return {"success": False, "message": f"API connection error: {str(e)}"}


# ═══════════════════════════════════════════════════════════════════════════════
#  Tool Dispatcher — maps intent → tool call
# ═══════════════════════════════════════════════════════════════════════════════

async def dispatch_tool(
    intent_type: str,
    parsed_data: Dict[str, Any],
    raw_text: str,
    user_token: str,
    user_role: str = "Customer"
) -> Dict[str, Any]:
    """
    Central dispatcher — routes parsed intent to the correct tool function.
    Returns a unified tool result dict with success, message, and optional data.
    """

    if intent_type in ("DIRECT_ORDER", "RATE_INQUIRY"):
        return await process_customer_grocery_intent(
            raw_text=raw_text,
            user_token=user_token,
            business_id=parsed_data.get("business_id"),
            intent_type=intent_type,
            target_mode=parsed_data.get("mode", "OPEN_NETWORK")
        )

    elif intent_type == "SUBSCRIPTION_VACATION":
        sub_id = parsed_data.get("subscription_id", "")
        if not sub_id:
            return {
                "success": False,
                "message": "Subscription ID provide karein. App mein apni active subscriptions check karein.",
                "requires_subscription_selection": True
            }
        return await pause_subscription(
            subscription_id=sub_id,
            pause_days=int(parsed_data.get("pause_days", 5)),
            user_token=user_token,
            reason=parsed_data.get("reason", "Vacation Mode")
        )

    elif intent_type == "DRIVER_BANNER":
        return await create_driver_trip_banner(
            origin=parsed_data.get("origin", "Origin"),
            destination=parsed_data.get("destination", "Destination"),
            departure_time=parsed_data.get("departure_time", "Tomorrow Morning"),
            fare_amount=float(parsed_data.get("fare_amount", 1500)),
            available_seats=int(parsed_data.get("available_seats", 3)),
            user_token=user_token
        )

    elif intent_type == "COMMUNITY_SOCIAL":
        return await post_social_meetup(
            category=parsed_data.get("category", "Coffee Meetup"),
            proposed_time=parsed_data.get("time", "Tomorrow 5 PM"),
            venue_preference=parsed_data.get("venue", "Nearby Public Cafe"),
            max_radius_km=int(parsed_data.get("radius_km", 3)),
            user_token=user_token
        )

    elif intent_type == "COMMUNITY_BOUNTY":
        return await post_community_classified(
            role_needed=parsed_data.get("role_needed", "Home Tutor"),
            description=raw_text,
            budget_monthly=float(parsed_data.get("budget_monthly", 600)),
            radius_km=int(parsed_data.get("radius_km", 3)),
            child_age=parsed_data.get("child_age"),
            user_token=user_token
        )

    elif intent_type == "KHATA_RECORD":
        return await record_khata_transaction(
            business_id=parsed_data.get("business_id", ""),
            customer_id=parsed_data.get("customer_id", ""),
            amount=float(parsed_data.get("amount", 0)),
            entry_type=parsed_data.get("entry_type", "DuesDebit"),
            notes=parsed_data.get("notes", raw_text),
            user_token=user_token,
            confirmed=bool(parsed_data.get("confirmed", False))
        )

    else:
        # GENERAL_QUERY — no tool call, just parse and reply
        return {
            "success": True,
            "tool_called": False,
            "message": f"ShopConnector AI: Aapka request receive hua — '{raw_text}'. Koi specific action nahi detect hua. Kya order karna hai ya koi aur help chahiye?"
        }
