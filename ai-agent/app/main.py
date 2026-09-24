import os
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from .models import ParseIntentRequest, ParseIntentResponse
from .intent_parser import parse_conversational_intent, parse_items_from_text

app = FastAPI(
    title="ShopConnector AI Agent Microservice",
    version="1.0.0",
    description="Conversational AI & Semantic Parser for Multi-Tenant Mobility, Grocery & Local Services (Native Windows)"
)

# Enable CORS for local Flutter App & .NET API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def health_check():
    return {
        "status": "online",
        "service": "ShopConnector AI Agent Microservice",
        "version": "1.0.0",
        "environment": "Native Windows (No Docker)",
        "supported_intents": [
            "DIRECT_ORDER",
            "RATE_INQUIRY",
            "DRIVER_BANNER",
            "COMMUNITY_SOCIAL",
            "COMMUNITY_BOUNTY",
            "SUBSCRIPTION_VACATION"
        ]
    }

@app.post("/api/v1/ai/parse-intent", response_model=ParseIntentResponse)
def parse_intent(request: ParseIntentRequest):
    """
    Parses conversational user query in Hindi, English, or Hinglish.
    Identifies intent, standardizes items, extracts numbers and dates, and determines action mode.
    """
    if not request.text or not request.text.strip():
        raise HTTPException(status_code=400, detail="Query text cannot be empty.")
        
    result = parse_conversational_intent(request.text, user_role=request.user_role or "Customer")
    return result

@app.post("/api/v1/ai/parse-grocery")
def parse_grocery(request: ParseIntentRequest):
    """
    Dedicated endpoint to parse spoken grocery lists (e.g., '5kg aaloo, 2 kg pyaz, 1 kg tomato').
    """
    items = parse_items_from_text(request.text)
    return {
        "raw_text": request.text,
        "items_count": len(items),
        "items": [item.model_dump() for item in items]
    }

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
