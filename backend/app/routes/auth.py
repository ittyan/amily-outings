import hashlib
import uuid

from fastapi import APIRouter, HTTPException

from app.schemas import AuthRequest, AuthResponse

router = APIRouter()


@router.post("/verify", response_model=AuthResponse)
def verify_auth(payload: AuthRequest) -> AuthResponse:
    provider = payload.provider.lower()
    if provider not in {"apple", "google"}:
        raise HTTPException(status_code=400, detail="Unsupported provider")

    token_hash = hashlib.sha256(payload.token.encode("utf-8")).hexdigest()
    user_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"{provider}:{token_hash}"))
    session_token = hashlib.sha256(f"{user_id}:{token_hash}".encode("utf-8")).hexdigest()

    return AuthResponse(user_id=user_id, session_token=session_token, is_admin=False)
