import os
import uvicorn
from fastapi import FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from pydantic import BaseModel, Field
from .models import ParseIntentRequest, ParseIntentResponse
from .intent_parser import parse_conversational_intent, parse_items_from_text
from .tool_engine import dispatch_tool, parse_grocery_voice_order

app = FastAPI(
    title="ShopConnector AI Agent Microservice",
    version="2.0.0",
    description=(
        "Conversational AI & Deterministic Tool Calling Engine for "
        "Multi-Tenant Mobility, Grocery & Local Services (Native Windows). "
        "Supports voice grocery parsing, subscription vacation mode, Khata transactions, "
        "driver intercity banners, community meetups, and skill bounties."
    )
)

# Enable CORS for local Flutter App & .NET API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response Models ────────────────────────────────────────────────

class AgentActionRequest(BaseModel):
    """Full agentic action request — parses intent AND executes the tool."""
    text: str = Field(..., description="Spoken or typed query in Hindi, Hinglish, or English")
    user_id: Optional[str] = None
    user_role: Optional[str] = "Customer"
    business_id: Optional[str] = None
    # Extra context for tool execution
    subscription_id: Optional[str] = None
    confirmed: Optional[bool] = False  # For financial confirmation guardrail


class ToolActionResult(BaseModel):
    success: bool
    intent_type: str
    parsed_reply: str
    tool_result: Optional[dict] = None
    requires_confirmation: Optional[bool] = False
    tool_called: bool = False


# ── Health Check ─────────────────────────────────────────────────────────────

@app.get("/")
def health_check():
    return {
        "status": "online",
        "service": "ShopConnector AI Agent Microservice",
        "version": "2.0.0",
        "environment": "Native Windows (No Docker)",
        "supported_intents": [
            "DIRECT_ORDER",
            "RATE_INQUIRY",
            "DRIVER_BANNER",
            "COMMUNITY_SOCIAL",
            "COMMUNITY_BOUNTY",
            "SUBSCRIPTION_VACATION",
            "KHATA_RECORD",
            "GENERAL_QUERY"
        ],
        "tools": [
            "parse_grocery_voice_order",
            "process_customer_grocery_intent",
            "pause_subscription",
            "record_khata_transaction",
            "create_driver_trip_banner",
            "post_social_meetup",
            "post_community_classified"
        ]
    }


# ── Parse Only (no tool execution) ──────────────────────────────────────────

@app.post("/api/v1/ai/parse-intent", response_model=ParseIntentResponse)
def parse_intent(request: ParseIntentRequest):
    """
    Parses conversational user query in Hindi, English, or Hinglish.
    Identifies intent, standardizes items, extracts numbers and dates, and determines action mode.
    Does NOT execute any action — use /api/v1/ai/act for full execution.
    """
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Query text cannot be empty.")

    result = parse_conversational_intent(request.text, user_role=request.user_role or "Customer")
    return result


@app.post("/api/v1/ai/parse-grocery")
def parse_grocery(request: ParseIntentRequest):
    """
    Dedicated endpoint to parse spoken grocery lists (e.g., '5kg aaloo, 2 kg pyaz, 1 kg tomato').
    Returns structured JSON items only — no tool execution.
    """
    items = parse_items_from_text(request.text)
    return {
        "raw_text": request.text,
        "items_count": len(items),
        "items": [item.model_dump() for item in items]
    }


# ── Agentic Execution (parse + execute tool) ─────────────────────────────────

@app.post("/api/v1/ai/act", response_model=ToolActionResult)
async def agentic_act(
    request: AgentActionRequest,
    authorization: Optional[str] = Header(None)
):
    """
    FULL AGENTIC ACTION:
    1. Parses the natural language intent.
    2. Enriches parsed_data with request context (subscription_id, business_id, etc.).
    3. Calls the appropriate deterministic tool against the .NET API.
    4. Returns the combined parse + tool result.

    Requires Authorization: Bearer {jwt_token} for mutating actions.
    """
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Query text cannot be empty.")

    # Step 1: Parse intent
    parsed = parse_conversational_intent(request.text, user_role=request.user_role or "Customer")

    # Step 2: Enrich parsed_data with request-level context
    if request.business_id:
        parsed.parsed_data["business_id"] = request.business_id
    if request.subscription_id:
        parsed.parsed_data["subscription_id"] = request.subscription_id
    if request.confirmed:
        parsed.parsed_data["confirmed"] = request.confirmed

    # Step 3: Extract JWT token
    token = ""
    if authorization and authorization.startswith("Bearer "):
        token = authorization[7:]

    # Step 4: Dispatch to tool engine
    tool_result = None
    tool_called = False

    if token:
        tool_result = await dispatch_tool(
            intent_type=parsed.intent_type,
            parsed_data=parsed.parsed_data,
            raw_text=request.text,
            user_token=token,
            user_role=request.user_role or "Customer"
        )
        tool_called = tool_result.get("tool_called", True) if tool_result else False

        # If tool requires confirmation, use tool message as reply
        if tool_result and tool_result.get("requires_confirmation"):
            return ToolActionResult(
                success=False,
                intent_type=parsed.intent_type,
                parsed_reply=tool_result["message"],
                tool_result=tool_result,
                requires_confirmation=True,
                tool_called=False
            )
    else:
        # No token — return parsed intent only, ask user to login
        return ToolActionResult(
            success=False,
            intent_type=parsed.intent_type,
            parsed_reply=f"{parsed.reply_message} (Login required to execute this action.)",
            tool_result=None,
            tool_called=False
        )

    # Step 5: Compose final reply
    final_reply = parsed.reply_message
    if tool_result and tool_result.get("success"):
        final_reply = tool_result.get("message", parsed.reply_message)

    return ToolActionResult(
        success=tool_result.get("success", False) if tool_result else False,
        intent_type=parsed.intent_type,
        parsed_reply=final_reply,
        tool_result=tool_result,
        tool_called=tool_called
    )


# ── Quick Tools (no auth required for read-only) ────────────────────────────

@app.post("/api/v1/ai/parse-voice-order")
def parse_voice_order_tool(request: ParseIntentRequest):
    """
    Tool 1: parse_grocery_voice_order
    Structures a voice/text grocery list into JSON items.
    No auth required — pure parsing, no mutation.
    """
    if not request.text:
        raise HTTPException(status_code=400, detail="text is required")
    return parse_grocery_voice_order(request.text)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
