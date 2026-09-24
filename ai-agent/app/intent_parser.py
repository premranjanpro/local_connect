import re
from typing import List, Tuple, Dict, Any
from .models import GroceryItem, ParseIntentResponse

# Bilingual Hinglish dictionary for common grocery & kirana staples
ITEM_MAPPING = {
    "aaloo": ("Potato", "kg"),
    "aalu": ("Potato", "kg"),
    "potato": ("Potato", "kg"),
    "pyaz": ("Onion", "kg"),
    "pyaj": ("Onion", "kg"),
    "pyag": ("Onion", "kg"),
    "pyaaz": ("Onion", "kg"),
    "pyazz": ("Onion", "kg"),
    "onion": ("Onion", "kg"),
    "kanda": ("Onion", "kg"),
    "tamatar": ("Tomato", "kg"),
    "tomato": ("Tomato", "kg"),
    "tamater": ("Tomato", "kg"),
    "doodh": ("Fresh Milk", "litre"),
    "dudh": ("Fresh Milk", "litre"),
    "milk": ("Fresh Milk", "litre"),
    "bread": ("White/Brown Bread", "packet"),
    "paneer": ("Fresh Paneer", "g"),
    "namak": ("Iodized Salt", "packet"),
    "salt": ("Iodized Salt", "packet"),
    "atta": ("Chakki Atta", "kg"),
    "aata": ("Chakki Atta", "kg"),
    "flour": ("Chakki Atta", "kg"),
    "cheeni": ("Sugar", "kg"),
    "chini": ("Sugar", "kg"),
    "sugar": ("Sugar", "kg"),
    "tel": ("Cooking Oil", "litre"),
    "oil": ("Cooking Oil", "litre"),
    "chai": ("Tea Leaves", "packet"),
    "chai patti": ("Tea Leaves", "packet"),
    "tea": ("Tea Leaves", "packet"),
    "chawal": ("Basmati Rice", "kg"),
    "rice": ("Basmati Rice", "kg"),
    "dal": ("Toor/Moong Dal", "kg"),
    "daal": ("Toor/Moong Dal", "kg"),
    "dahi": ("Curd / Yogurt", "packet"),
    "curd": ("Curd / Yogurt", "packet"),
    "maggi": ("Maggi Instant Noodles", "packet"),
    "biscuit": ("Parle-G / GoodDay", "packet"),
    "biscuits": ("Parle-G / GoodDay", "packet")
}

def parse_items_from_text(text: str) -> List[GroceryItem]:
    """
    Parses items like: '5kg aaloo, 2 kg pyag, 1 kg tomato' or '2 packet doodh aur 1 bread'
    """
    items: List[GroceryItem] = []
    
    # Pattern to match: [quantity] [optional unit] [item name]
    # e.g., '5kg aaloo', '2 kg pyaz', '1 kg tomato', '500g paneer', '2 packet doodh'
    patterns = [
        r"(\d+(?:\.\d+)?)\s*(kg|kilo|kgs|g|gm|gram|packet|pkt|litre|liter|ltr|l|piece|pc|pcs)?\s+([a-zA-Z\s]+?)(?:,|$|\band\b|\baur\b)",
        r"([a-zA-Z\s]+?)\s+(\d+(?:\.\d+)?)\s*(kg|kilo|kgs|g|gm|gram|packet|pkt|litre|liter|ltr|l|piece|pc|pcs)"
    ]
    
    # Clean text
    clean_text = text.lower().replace("chahiye", "").replace("bhejo", "").replace("mujhe", "").strip()
    
    # Segment by commas, aur, and
    segments = re.split(r",|\baur\b|\band\b", clean_text)
    
    for seg in segments:
        seg = seg.strip()
        if not seg:
            continue
            
        matched = False
        # Try Regex 1: quantity + unit + item
        m = re.search(r"(\d+(?:\.\d+)?)\s*(kg|kilo|kgs|g|gm|gram|packet|pkt|litre|liter|ltr|l|piece|pc|pcs)?\s+([a-zA-Z\s]+)", seg)
        if m:
            qty = float(m.group(1))
            unit = m.group(2) or "kg"
            raw_item = m.group(3).strip()
            
            # Map unit
            unit = "kg" if unit in ["kg", "kilo", "kgs"] else unit
            unit = "g" if unit in ["g", "gm", "gram"] else unit
            unit = "litre" if unit in ["litre", "liter", "ltr", "l"] else unit
            unit = "packet" if unit in ["packet", "pkt"] else unit
            unit = "piece" if unit in ["piece", "pc", "pcs"] else unit
            
            # Match dictionary
            norm_name = raw_item.title()
            for key, (canonical, def_unit) in ITEM_MAPPING.items():
                if key in raw_item:
                    norm_name = canonical
                    if not m.group(2): # If user didn't specify unit, use default
                        unit = def_unit
                    break
            
            items.append(GroceryItem(
                raw_name=raw_item,
                normalized_name=norm_name,
                quantity=qty,
                unit=unit
            ))
            matched = True
            
        if not matched:
            # Check if any staple word is in this segment
            for key, (canonical, def_unit) in ITEM_MAPPING.items():
                if re.search(rf"\b{key}\b", seg):
                    items.append(GroceryItem(
                        raw_name=key,
                        normalized_name=canonical,
                        quantity=1.0,
                        unit=def_unit
                    ))
                    break

    return items

def parse_conversational_intent(text: str, user_role: str = "Customer") -> ParseIntentResponse:
    t = text.lower()
    
    # 1. Driver Intercity Route Banner
    # e.g.: "jaipur se delhi ke liye availabe h kal 11 bje se 1500 lenge"
    if ("se" in t or "to" in t) and ("delhi" in t or "jaipur" in t or "mumbai" in t or "available" in t or "chalenge" in t):
        origin = "Jaipur" if "jaipur" in t else "Origin City"
        destination = "Delhi" if "delhi" in t else "Destination City"
        fare_match = re.search(r"(\d{3,5})\s*(?:rs|rupaye|lenge|charge|kiraya)?", t)
        fare = float(fare_match.group(1)) if fare_match else 1500.0
        
        return ParseIntentResponse(
            intent_type="DRIVER_BANNER",
            confidence=0.95,
            target_mode="BROADCAST",
            parsed_data={
                "origin": origin,
                "destination": destination,
                "departure_time": "Tomorrow 11:00 AM",
                "fare_amount": fare,
                "available_seats": 3
            },
            reply_message=f"Driver route banner ban gaya hai: {origin} se {destination}, kal 11:00 AM, Fare: ₹{int(fare)}/seat. Yeh route nearby customers ko broadcast kar diya gaya hai."
        )

    # 2. Community Dating / Social Meetup
    # e.g.: "koi ladki free for coffee tomorrow 5 pm" or "dating coffee date"
    if any(k in t for k in ["dating", "coffee", "meetup", "free for coffee", "date tomorrow"]):
        time_match = re.search(r"(\d{1,2}(?::\d{2})?\s*(?:am|pm|baje))", t)
        time_str = time_match.group(1) if time_match else "Tomorrow 5:00 PM"
        return ParseIntentResponse(
            intent_type="COMMUNITY_SOCIAL",
            confidence=0.92,
            target_mode="OPEN_NETWORK",
            parsed_data={
                "category": "Coffee Meetup & Dating",
                "time": time_str,
                "venue": "Nearby Verified Public Cafe (Blue Tokai / CCD)"
            },
            reply_message=f"Aapka meetup post draft ho gaya hai: 'Casual Coffee Meetup' {time_str}. Verified public cafe venue ke sath community feed par publish kiya gaya hai."
        )

    # 3. Community Tutor / Skill Bounty
    # e.g.: "need teacher for my kids 5 year budget 600 monthly"
    if any(k in t for k in ["teacher", "tutor", "kids", "padhane", "bachhe", "budget"]):
        budget_match = re.search(r"(\d{3,5})", t)
        budget = float(budget_match.group(1)) if budget_match else 600.0
        age_match = re.search(r"(\d+)\s*(?:year|saal)", t)
        kid_age = int(age_match.group(1)) if age_match else 5
        
        return ParseIntentResponse(
            intent_type="COMMUNITY_BOUNTY",
            confidence=0.94,
            target_mode="OPEN_NETWORK",
            parsed_data={
                "role_needed": "Home Tutor",
                "child_age": kid_age,
                "budget_monthly": budget
            },
            reply_message=f"Home Tutor requirement post ho gayi hai: {kid_age} saal ke bachhe ke liye, Monthly Budget ₹{int(budget)}. Nearby colony teachers ko alert notify kiya gaya hai."
        )

    # 4. Daily Morning Subscription Vacation Mode
    # e.g.: "kal se 5 din tak milk delivery pause kar do"
    if any(k in t for k in ["pause", "chutti", "vacation", "doodh pause", "milk delivery pause"]):
        days_match = re.search(r"(\d+)\s*(?:din|days)", t)
        pause_days = int(days_match.group(1)) if days_match else 5
        return ParseIntentResponse(
            intent_type="SUBSCRIPTION_VACATION",
            confidence=0.96,
            target_mode="SINGLE_SHOP",
            parsed_data={
                "product": "Daily Morning Milk",
                "pause_days": pause_days,
                "billing_action": "Auto-deducted from month-end Khata bill"
            },
            reply_message=f"Aapki milk delivery kal se {pause_days} din ke liye pause kar di gayi hai (₹0 charge). Month-end par yeh {pause_days} din aapke Khata bill se auto-deduct ho jayenge."
        )

    # 5. Grocery Parsing (Rate Inquiry vs Direct Order)
    items = parse_items_from_text(text)
    if items:
        # Detect Mode: Single Shop vs 3 Shops vs Open Network
        target_mode = "OPEN_NETWORK"
        if "tin" in t or "teen" in t or "3 shop" in t or "3 dukan" in t or "three" in t:
            target_mode = "THREE_SHOPS"
        elif "sharma" in t or "gupta" in t or "apne shopkeeper" in t or "ek shop" in t or "dukan" in t:
            target_mode = "SINGLE_SHOP"
            
        # Detect Intent: Rate Inquiry / RFQ vs Direct Order
        is_rate_inquiry = any(k in t for k in ["rate", "bhav", "quote", "rate mango", "rate batao", "kitne ka", "pucho"])
        
        intent_type = "RATE_INQUIRY" if is_rate_inquiry else "DIRECT_ORDER"
        
        item_summary = ", ".join([f"{item.quantity} {item.unit} {item.normalized_name}" for item in items])
        
        if intent_type == "RATE_INQUIRY":
            reply = f"Maine aapki list structure kar li hai: {item_summary}. Mode: {target_mode}. Ab shops se rate quotes maang kar comparative rate card banaya ja raha hai."
        else:
            reply = f"Aapka order ready ho gaya hai: {item_summary}. Shopkeeper ko list bhej di gayi hai. Doorstep delivery par Cash ya Shopkeeper Dues/Khata dono mode available hain."
            
        return ParseIntentResponse(
            intent_type=intent_type,
            confidence=0.95,
            target_mode=target_mode,
            items=items,
            parsed_data={
                "item_count": len(items),
                "items_list": [item.model_dump() for item in items],
                "mode": target_mode
            },
            reply_message=reply
        )
        
    # Default fallback
    return ParseIntentResponse(
        intent_type="GENERAL_QUERY",
        confidence=0.70,
        target_mode="OPEN_NETWORK",
        reply_message=f"Maine aapka request receive kar liya hai: '{text}'. ShopConnector AI Assistant aapki help ke liye ready hai."
    )
