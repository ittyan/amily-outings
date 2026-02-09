from __future__ import annotations

import math
from typing import Iterable, List, Optional, Set

from sqlalchemy import select, delete

from app import models
from app.db import session_scope
from app.schemas import Spot, SpotDetail


def seed_spots() -> None:
    with session_scope() as session:
        existing = session.execute(select(models.Spot.id).limit(1)).scalar()
        if existing:
            return
        session.add_all(
            [
                models.Spot(
                    id="tokyo-park-1",
                    name="千代田こども公園",
                    lat=35.6895,
                    lng=139.6917,
                    address="東京都千代田区",
                    summary="駅近の小さな公園。滑り台と砂場あり。",
                    official_url=None,
                    cost_range="FREE",
                    age_min=0,
                    age_max=8,
                    tags=["屋外", "ベビーカーOK"],
                    images=[],
                    hours="9:00-17:00",
                ),
                models.Spot(
                    id="tokyo-museum-1",
                    name="科学体験ミュージアム",
                    lat=35.6852,
                    lng=139.7528,
                    address="東京都千代田区",
                    summary="親子向け体験展示。雨の日にもおすすめ。",
                    official_url="https://example.com",
                    cost_range="U1000",
                    age_min=3,
                    age_max=12,
                    tags=["屋内", "雨でもOK", "授乳室"],
                    images=[],
                    hours="10:00-18:00",
                ),
            ]
        )


# --- Filtering helpers

def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def list_spots(
    *,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    radius_km: float = 5.0,
    q: Optional[str] = None,
    tags: Optional[Set[str]] = None,
    age: Optional[int] = None,
    cost_range: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
) -> List[Spot]:
    seed_spots()
    with session_scope() as session:
        spots = session.execute(select(models.Spot)).scalars().all()

    items: Iterable[models.Spot] = spots
    if lat is not None and lng is not None:
        items = [s for s in items if _haversine_km(lat, lng, s.lat, s.lng) <= radius_km]

    if q:
        qn = q.lower()
        items = [
            s
            for s in items
            if qn in s.name.lower()
            or qn in s.address.lower()
            or qn in s.summary.lower()
            or any(qn in t.lower() for t in s.tags)
        ]

    if tags:
        items = [s for s in items if not tags.isdisjoint(set(s.tags))]

    if age is not None:
        items = [
            s
            for s in items
            if (s.age_min is None or age >= s.age_min)
            and (s.age_max is None or age <= s.age_max)
        ]

    if cost_range:
        items = [s for s in items if s.cost_range == cost_range]

    items = list(items)[offset : offset + limit]
    return [_to_spot(s) for s in items]


def get_spot(spot_id: str) -> Optional[SpotDetail]:
    seed_spots()
    with session_scope() as session:
        spot = session.get(models.Spot, spot_id)
        if not spot:
            return None
        return _to_spot_detail(spot)


def get_favorites(user_id: str) -> List[Spot]:
    seed_spots()
    with session_scope() as session:
        rows = session.execute(
            select(models.Spot).join(
                models.Favorite, models.Favorite.spot_id == models.Spot.id
            ).where(models.Favorite.user_id == user_id)
        ).scalars().all()
    return [_to_spot(s) for s in rows]


def add_favorite(user_id: str, spot_id: str) -> bool:
    seed_spots()
    with session_scope() as session:
        spot = session.get(models.Spot, spot_id)
        if not spot:
            return False
        existing = session.execute(
            select(models.Favorite).where(
                models.Favorite.user_id == user_id,
                models.Favorite.spot_id == spot_id,
            )
        ).scalar()
        if not existing:
            session.add(models.Favorite(user_id=user_id, spot_id=spot_id))
    return True


def remove_favorite(user_id: str, spot_id: str) -> None:
    with session_scope() as session:
        session.execute(
            delete(models.Favorite).where(
                models.Favorite.user_id == user_id,
                models.Favorite.spot_id == spot_id,
            )
        )


def _to_spot(row: models.Spot) -> Spot:
    return Spot(
        id=row.id,
        name=row.name,
        lat=row.lat,
        lng=row.lng,
        address=row.address,
        summary=row.summary,
        official_url=row.official_url,
        cost_range=row.cost_range,
        age_min=row.age_min,
        age_max=row.age_max,
        tags=row.tags or [],
        images=row.images or [],
    )


def _to_spot_detail(row: models.Spot) -> SpotDetail:
    return SpotDetail(
        id=row.id,
        name=row.name,
        lat=row.lat,
        lng=row.lng,
        address=row.address,
        summary=row.summary,
        official_url=row.official_url,
        cost_range=row.cost_range,
        age_min=row.age_min,
        age_max=row.age_max,
        tags=row.tags or [],
        images=row.images or [],
        hours=row.hours,
    )
