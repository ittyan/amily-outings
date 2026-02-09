from typing import Optional, Set

from fastapi import APIRouter, Query

from app.schemas import Spot, SpotDetail
from app import store

router = APIRouter()


@router.get("", response_model=list[Spot])
def list_spots(
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    radius_km: float = Query(default=5.0, ge=0.1, le=50.0),
    q: Optional[str] = None,
    tags: Optional[str] = None,
    age: Optional[int] = Query(default=None, ge=0, le=18),
    cost_range: Optional[str] = None,
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[Spot]:
    tag_set: Optional[Set[str]] = None
    if tags:
        tag_set = {t.strip() for t in tags.split(",") if t.strip()}

    return store.list_spots(
        lat=lat,
        lng=lng,
        radius_km=radius_km,
        q=q,
        tags=tag_set,
        age=age,
        cost_range=cost_range,
        limit=limit,
        offset=offset,
    )


@router.get("/{spot_id}", response_model=SpotDetail)
def get_spot(spot_id: str) -> SpotDetail:
    spot = store.get_spot(spot_id)
    if not spot:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="Spot not found")
    return spot
