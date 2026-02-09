import hashlib
import json
import os
import time
import uuid

import jwt
import requests
from fastapi import APIRouter, HTTPException

from app.schemas import AuthRequest, AuthResponse

router = APIRouter()

APPLE_ISSUER = os.getenv("APPLE_ISSUER", "https://appleid.apple.com")
APPLE_JWKS_URL = os.getenv("APPLE_JWKS_URL", "https://appleid.apple.com/auth/keys")
APPLE_CLIENT_ID = os.getenv("APPLE_CLIENT_ID", "com.ittyan.FamilyOutings")

_JWKS_CACHE: dict | None = None
_JWKS_EXPIRES_AT: float = 0.0


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _get_apple_jwks() -> dict:
    global _JWKS_CACHE, _JWKS_EXPIRES_AT
    now = time.time()
    if _JWKS_CACHE and now < _JWKS_EXPIRES_AT:
        return _JWKS_CACHE
    resp = requests.get(APPLE_JWKS_URL, timeout=5)
    resp.raise_for_status()
    _JWKS_CACHE = resp.json()
    _JWKS_EXPIRES_AT = now + 3600
    return _JWKS_CACHE


def _verify_apple_token(id_token: str, nonce: str | None) -> dict:
    header = jwt.get_unverified_header(id_token)
    kid = header.get("kid")
    if not kid:
        raise HTTPException(status_code=400, detail="Missing token header")

    jwks = _get_apple_jwks()
    keys = jwks.get("keys", [])
    key = next((k for k in keys if k.get("kid") == kid), None)
    if not key:
        raise HTTPException(status_code=400, detail="Unknown signing key")

    public_key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(key))
    decoded = jwt.decode(
        id_token,
        public_key,
        algorithms=["RS256"],
        audience=APPLE_CLIENT_ID,
        issuer=APPLE_ISSUER,
    )

    if nonce:
        token_nonce = decoded.get("nonce")
        if not token_nonce:
            raise HTTPException(status_code=400, detail="Missing nonce in token")
        if token_nonce != _sha256(nonce):
            raise HTTPException(status_code=400, detail="Invalid nonce")

    return decoded


@router.post("/verify", response_model=AuthResponse)
def verify_auth(payload: AuthRequest) -> AuthResponse:
    provider = payload.provider.lower()
    if provider != "apple":
        raise HTTPException(status_code=400, detail="Unsupported provider")

    decoded = _verify_apple_token(payload.token, payload.nonce)
    sub = decoded.get("sub")
    if not sub:
        raise HTTPException(status_code=400, detail="Missing subject")

    user_id = f"apple:{sub}"
    session_token = _sha256(f"{user_id}:{uuid.uuid4()}")
    return AuthResponse(user_id=user_id, session_token=session_token, is_admin=False)
