from fastapi import APIRouter, Header, HTTPException

from app.schemas import FavoriteRequest, FavoritesResponse
from app import store

router = APIRouter()


def _require_user_id(user_id: str | None) -> str:
    if not user_id:
        raise HTTPException(status_code=401, detail="Missing X-User-Id header")
    return user_id


@router.get("", response_model=FavoritesResponse)
def list_favorites(x_user_id: str | None = Header(default=None)) -> FavoritesResponse:
    user_id = _require_user_id(x_user_id)
    items = store.get_favorites(user_id)
    return FavoritesResponse(items=items)


@router.post("")
def add_favorite(
    payload: FavoriteRequest, x_user_id: str | None = Header(default=None)
) -> dict:
    user_id = _require_user_id(x_user_id)
    ok = store.add_favorite(user_id, payload.spot_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Spot not found")
    return {"ok": True}


@router.delete("/{spot_id}")
def remove_favorite(spot_id: str, x_user_id: str | None = Header(default=None)) -> dict:
    user_id = _require_user_id(x_user_id)
    store.remove_favorite(user_id, spot_id)
    return {"ok": True}
