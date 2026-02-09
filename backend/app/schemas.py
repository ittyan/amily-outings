from typing import List, Optional
from pydantic import BaseModel


class Spot(BaseModel):
    id: str
    name: str
    lat: float
    lng: float
    address: str
    summary: str
    official_url: Optional[str] = None
    cost_range: Optional[str] = None
    age_min: Optional[int] = None
    age_max: Optional[int] = None
    tags: List[str] = []
    images: List[str] = []


class SpotDetail(Spot):
    hours: Optional[str] = None


class FavoriteRequest(BaseModel):
    spot_id: str


class AuthRequest(BaseModel):
    provider: str
    token: str


class AuthResponse(BaseModel):
    user_id: str
    session_token: str
    is_admin: bool = False


class FavoritesResponse(BaseModel):
    items: List[Spot]
