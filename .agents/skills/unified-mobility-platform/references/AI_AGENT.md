# Python AI Agent Microservice (`ai-agent`)

## 1. Principle & Architecture

The **AI Agent** is built as an **independent, standalone Python microservice** (`ai-agent/`) running on FastAPI and native Python (Port 8000). It serves as a unified conversational intelligence layer for all three platform personas:
1. **Customer** (Order placement, voice shopping, "Mera order/cab kahan hai?", live tracking ETA).
2. **Shopkeeper** ("Atta aur doodh out of stock kar do", "Aaj kitne orders aaye aur kitni sale hui?").
3. **Delivery Boy / Driver** ("Agla pickup point kahan hai?", "Aaj ki total earning kitni hui?", hands-free voice assistance).

The AI agent communicates with the **ASP.NET Core Web API** via secure REST and SignalR endpoints using mutual service-to-service API tokens.

```
+-----------------------------------------------------------------------------------------+
|                                PYTHON AI AGENT MICROSERVICE                             |
|                                (FastAPI / Native Python on Port 8000)                   |
|                                                                                         |
|       +-------------------------------------------------------------------------+       |
|       |                     Pluggable LLM Provider Layer                        |       |
|       |   [Current: Grok (xAI API) | Swappable to: Gemini, Claude, Ollama]     |       |
|       +-------------------------------------------------------------------------+       |
|                                           |                                             |
|                   +-----------------------+-----------------------+                     |
|                   |                                               |                     |
|                   v                                               v                     |
|     +---------------------------+                   +---------------------------+       |
|     |  Multi-Role System Prompts|                   |  Deterministic Tool Engine|       |
|     |  - Customer Persona       |                   |  - get_order_status       |       |
|     |  - Shopkeeper Persona     |                   |  - get_driver_live_loc    |       |
|     |  - Driver Persona         |                   |  - update_product_stock   |       |
|     +---------------------------+                   |  - get_driver_earnings    |       |
|                                                     +---------------------------+       |
|                                                                   |                     |
+-------------------------------------------------------------------|---------------------+
                                                                    v (REST / Service Token)
                                                +---------------------------------------+
                                                |     ASP.NET Core 8 Web API (5000)     |
                                                |     PostgreSQL Core DB / Redis Cache  |
                                                +---------------------------------------+
```

---

## 2. Pluggable LLM Provider Architecture (Starting with Grok)

The system uses a clean **Provider Interface pattern** so the underlying LLM can be swapped via an environment variable (`LLM_PROVIDER=grok`) without rewriting any business tools or prompts.

### Provider Interface & Grok Implementation

```python
# ai-agent/app/providers/base.py
from abc import ABC, abstractmethod
from typing import List, Dict, Any

class LLMProvider(ABC):
    @abstractmethod
    async def chat_completion(
        self, 
        messages: List[Dict[str, str]], 
        tools: List[Dict[str, Any]] = None,
        temperature: float = 0.3
    ) -> Dict[str, Any]:
        """Generate response with optional function/tool calling."""
        pass

# ai-agent/app/providers/grok_provider.py
import httpx
from .base import LLMProvider

class GrokProvider(LLMProvider):
    def __init__(self, api_key: str, model: str = "grok-2"):
        self.api_key = api_key
        self.model = model
        self.base_url = "https://api.x.ai/v1"

    async def chat_completion(self, messages, tools=None, temperature=0.3):
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature
        }
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(f"{self.base_url}/chat/completions", headers=headers, json=payload)
            response.raise_for_status()
            return response.json()
```

---

## 3. Multi-Role Conversational Capabilities

### 3.1 Customer Persona
- **Hindi / Hinglish Voice to Order**:
  - Customer: *"Bhaiya 1 kg Tata Namak aur 2 packet bread bhejo"*
  - Agent extracts structured item draft and searches nearby shop catalogs.
- **Apartment Voice Grocery List Parsing & Multi-Shop Intent Engine**:
  - Customer: *"Bhaiya mujhe 5kg aaloo, 2 kg pyaz, 1 kg tomato chahiye"*
  - **Intent Classification**: Agent detects whether user is asking for rates (`RATE_INQUIRY` - e.g. *"tino dukan se rate mango"*) or placing a direct order (`DIRECT_ORDER` - e.g. *"Gupta ji ko bolo turant bhej dein"*).
  - **3 Request Modes Supported**:
    - *Mode A (Single Shop)*: Direct order/quote to 1 selected shopkeeper.
    - *Mode B (Selective Multi-Shop)*: Requests quotes from 2 or 3 selected shops (e.g. Gupta, Sharma, Verma) and renders comparative rate card.
    - *Mode C (Open Network)*: Broadcasts RFQ across neighborhood vendors within 3-5 km.
  - Agent calls `process_customer_grocery_intent()`, standardizes bilingual items/units, and triggers quote requests or direct cart.
- **Realtime Ride & Order Tracking**:
  - Customer: *"Mera cab/delivery boy kahan tak pahuncha?"*
  - Agent calls tool `get_driver_live_location(task_id)` and responds with current road landmark and ETA in minutes.
- **Hyperlocal Social Meetups & Casual Dating**:
  - Customer: *"Kal sham 5 baje Blue Tokai par coffee date ke liye meetup post kar do"*
  - Agent extracts venue, category, and time, verifies safe public cafe venue, and calls `post_social_meetup()`.
- **Community Tutor & Skill Request Bounties**:
  - Parent: *"Mere 5 saal ke bache ke liye home tutor chahiye, budget ₹600 monthly, shaam 4 baje"*
  - Agent calls `post_community_classified()` with target age 5 and budget ₹600, broadcasting to nearby educated residents/tutors.
- **Daily Subscriptions Vacation Mode (1-Tap & Voice)**:
  - Customer: *"Kal se 5 din tak milk delivery pause kar do"*
  - Agent parses start/end dates, calls `pause_subscription()`, and confirms:
    *"Aapki milk delivery kal se 5 din ke liye pause kar di gayi hai (₹0 charge). Month-end par yeh 5 din bill se deduct ho jayenge."*
- **Service Request Assistant**:
  - Customer uploads photo/video of leaking tap: *"Plumber chahiye"*
  - Agent structures request, asks urgency, and drafts quote broadcast.

### 3.2 Shopkeeper Persona
- **Voice Inventory Management**:
  - Shopkeeper: *"Amul doodh 500ml khatam ho gaya hai, out of stock kar do"*
  - Agent calls `update_product_stock(business_id, sku, is_available=False)` and confirms: *"Amul doodh out-of-stock mark kar diya gaya hai."*
- **Digital Khata / Udhar Management**:
  - Shopkeeper: *"Sharma ji (Flat 302) ka dues mode on kar do, credit limit ₹3,000 rakhna"*
  - Agent calls `toggle_customer_khata()` and confirms: *"Sharma ji ke liye Udhar/Khata activate kar diya gaya hai (Limit: ₹3,000)."*
  - Shopkeeper: *"Aaj tak ka total bazaar udhar kitna baki hai?"*
  - Agent calculates outstanding ledger balance across all active customers.
- **Daily Performance & Order Queries**:
  - Shopkeeper: *"Aaj subah se kitne orders aaye aur kitni sale hui?"*
  - Agent calls `get_shop_summary(business_id)` and gives total order count, pending items, and total revenue.

### 3.3 Delivery Boy / Driver Persona
- **Hands-Free Driving Companion**:
  - Driver: *"Agla pickup kahan hai aur kitni door hai?"*
  - Agent calls `get_active_task_detail(driver_id)` and gives turn direction and landmark.
- **Doorstep Payment Guidance (Cash vs UPI vs Khata)**:
  - Driver: *"Customer keh raha hai udhar mein likh lo, kya karoon?"*
  - Agent checks customer's khata status: *"Customer ke account mein ₹2,000 tak ka udhar allowed hai. Aap 'Add to Khata' button daba sakte hain."*
- **Earnings & Trip Queries**:
  - Driver: *"Aaj ki meri earning kitni hui?"*
  - Agent calls `get_driver_earnings(driver_id)` and summarizes base pay, km earnings, and tips.
- **Dual OTP Prompting**:
  - Driver: *"Pickup point par pahunch gaya"*
  - Agent informs: *"Aap shopkeeper/sender se Pickup OTP maang kar verify kar lijiye."*
- **Inter-City Route Banners & Scheduled Rides**:
  - Driver speaks or types in AI Box: *"Jaipur se Delhi ke liye available hoon kal 11 bje se 1500 lenge, 3 seat khali hai"*
  - Agent parses route, time, pricing, and seats, calls `create_driver_trip_banner()`, and confirms:
    *"Aapka Jaipur se Delhi ka banner live ho gaya hai (₹1,500/seat, 3 seats). Customers ko broadcast notification bheji ja rahi hai."*

---

## 4. Deterministic Backend Tool Calling

The agent never guesses or hallucinates. It executes deterministic tools against the ASP.NET Core API:

```json
[
  {
    "type": "function",
    "function": {
      "name": "get_task_status_and_eta",
      "description": "Fetches current task status, driver location, and remaining ETA in minutes.",
      "parameters": {
        "type": "object",
        "properties": {
          "task_id": { "type": "string", "description": "UUID of the task" }
        },
        "required": ["task_id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "update_product_stock",
      "description": "Updates product availability and stock quantity for a shop.",
      "parameters": {
        "type": "object",
        "properties": {
          "business_id": { "type": "string" },
          "product_query": { "type": "string" },
          "is_available": { "type": "boolean" },
          "stock_qty": { "type": "integer" }
        },
        "required": ["business_id", "product_query", "is_available"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "get_driver_daily_earnings",
      "description": "Fetches total earnings and trip breakdown for a driver today.",
      "parameters": {
        "type": "object",
        "properties": {
          "driver_user_id": { "type": "string" }
        },
        "required": ["driver_user_id"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "create_driver_trip_banner",
      "description": "Publishes a scheduled inter-city route offer/banner (e.g. Jaipur to Delhi) and triggers customer broadcasts.",
      "parameters": {
        "type": "object",
        "properties": {
          "origin_city": { "type": "string" },
          "destination_city": { "type": "string" },
          "departure_time": { "type": "string", "description": "ISO-8601 timestamp" },
          "price_per_seat": { "type": "number" },
          "available_seats": { "type": "integer" },
          "description": { "type": "string" }
        },
        "required": ["origin_city", "destination_city", "departure_time", "price_per_seat"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "parse_grocery_voice_order",
      "description": "Parses spoken/typed Hindi, Hinglish, or English grocery text into structured items, quantities, and units.",
      "parameters": {
        "type": "object",
        "properties": {
          "raw_text": { "type": "string", "description": "e.g. '5kg aaloo, 2 kg pyag, 1 kg tomato'" },
          "apartment_vendor_business_id": { "type": "string" },
          "customer_user_id": { "type": "string" }
        },
        "required": ["raw_text"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "record_khata_transaction",
      "description": "Records an Udhar / Store credit order or debt repayment in customer digital ledger.",
      "parameters": {
        "type": "object",
        "properties": {
          "business_id": { "type": "string" },
          "customer_user_id": { "type": "string" },
          "order_id": { "type": "string" },
          "transaction_type": { "type": "string", "enum": ["DUES_ADDED", "PAYMENT_RECEIVED"] },
          "amount": { "type": "number" },
          "payment_mode": { "type": "string", "enum": ["CASH", "UPI_QR", "BANK_TRANSFER"] }
        },
        "required": ["business_id", "customer_user_id", "transaction_type", "amount"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "post_social_meetup",
      "description": "Publishes a public hangout or coffee date meetup with public geofenced venue verification.",
      "parameters": {
        "type": "object",
        "properties": {
          "creator_user_id": { "type": "string" },
          "meetup_type": { "type": "string", "enum": ["COFFEE_DATE", "SPORTS_BUDDY", "CASUAL_HANGOUT", "WALKING_BUDDY"] },
          "title": { "type": "string" },
          "meetup_venue_name": { "type": "string", "description": "Public cafe, mall, or park only" },
          "scheduled_at": { "type": "string", "description": "ISO-8601 timestamp" },
          "preferred_gender": { "type": "string", "enum": ["ANY", "FEMALE", "MALE"] }
        },
        "required": ["creator_user_id", "meetup_type", "title", "meetup_venue_name", "scheduled_at"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "post_community_classified",
      "description": "Posts a community task/bounty (e.g. kid tutor, maid, babysitter) to nearby residents.",
      "parameters": {
        "type": "object",
        "properties": {
          "requester_user_id": { "type": "string" },
          "category": { "type": "string", "enum": ["HOME_TUTOR", "MAID_COOK", "BABYSITTER", "PET_CARE", "APPLIANCE_REPAIR"] },
          "title": { "type": "string" },
          "target_child_age": { "type": "integer" },
          "budget_amount": { "type": "number" },
          "budget_frequency": { "type": "string", "enum": ["MONTHLY", "PER_HOUR", "PER_TASK"] },
          "preferred_timing": { "type": "string" }
        },
        "required": ["requester_user_id", "category", "title", "budget_amount"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "process_customer_grocery_intent",
      "description": "Determines whether customer wants price quotes (RATE_INQUIRY) or direct ordering (DIRECT_ORDER) across single shop, 3 selected shops, or open network.",
      "parameters": {
        "type": "object",
        "properties": {
          "raw_text": { "type": "string" },
          "rfq_mode": { "type": "string", "enum": ["DIRECT_SINGLE_SHOP", "MULTI_SHOP_SELECTIVE", "OPEN_NETWORK_BROADCAST"] },
          "target_business_ids": { 
            "type": "array", 
            "items": { "type": "string" },
            "description": "Optional list of 1 to 3 selected shop IDs" 
          },
          "detected_intent": { "type": "string", "enum": ["RATE_INQUIRY", "DIRECT_ORDER"] }
        },
        "required": ["raw_text", "rfq_mode", "detected_intent"]
      }
    }
  },
  {
    "type": "function",
    "function": {
      "name": "pause_subscription",
      "description": "Activates Vacation Mode on a recurring subscription (milk, newspaper, tiffin) for a specified date range.",
      "parameters": {
        "type": "object",
        "properties": {
          "customer_user_id": { "type": "string" },
          "product_category_or_id": { "type": "string", "description": "e.g. 'milk', 'newspaper', or UUID" },
          "pause_start_date": { "type": "string", "description": "YYYY-MM-DD" },
          "pause_end_date": { "type": "string", "description": "YYYY-MM-DD" },
          "reason": { "type": "string" }
        },
        "required": ["customer_user_id", "pause_start_date", "pause_end_date"]
      }
    }
  }
]
```

---

## 5. Strict Guardrails

1. **Confirmation for State & Money Changes**:
   - The AI agent CAN freely answer read-only questions ("Mera order kahan hai?", "Aaj ki earning kitni hui?").
   - The AI agent MUST request explicit user confirmation before placing orders, paying money, or accepting quotes.
2. **Never Reveal Sensitive Private Coordinates**:
   - The AI agent translates exact driver lat/lng into user-friendly landmark and ETA statements (e.g. *"Aapka driver Fraser Road par hai, lagbhag 4 minute mein pahunchega"*).
3. **No Hallucinated Quotes**:
   - The agent never manufactures provider quotes without backend verification.
