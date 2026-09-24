from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

class GroceryItem(BaseModel):
    raw_name: str = Field(..., description="Original item name from text")
    normalized_name: str = Field(..., description="Standardized English/Hindi catalog name")
    quantity: float = Field(..., description="Numeric quantity")
    unit: str = Field(..., description="Unit: kg, g, packet, litre, piece")

class ParseIntentRequest(BaseModel):
    text: str = Field(..., description="Spoken or typed natural language query in Hindi, Hinglish, or English")
    user_id: Optional[str] = None
    user_role: Optional[str] = "Customer"
    business_id: Optional[str] = None

class ParseIntentResponse(BaseModel):
    intent_type: str = Field(..., description="DIRECT_ORDER, RATE_INQUIRY, DRIVER_BANNER, COMMUNITY_SOCIAL, COMMUNITY_BOUNTY, SUBSCRIPTION_VACATION, GENERAL_QUERY")
    confidence: float
    target_mode: Optional[str] = Field("OPEN_NETWORK", description="SINGLE_SHOP, THREE_SHOPS, OPEN_NETWORK")
    items: List[GroceryItem] = []
    parsed_data: Dict[str, Any] = {}
    reply_message: str = Field(..., description="Natural language Hindi/English assistant reply")
