from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes import spots, auth, favorites
from app.db import init_db, check_db
from app.settings import settings

app = FastAPI(title="Family Outings API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(spots.router, prefix="/spots", tags=["spots"])
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(favorites.router, prefix="/favorites", tags=["favorites"])


@app.on_event("startup")
def startup() -> None:
    init_db()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/health/db")
def health_db():
    ok = check_db()
    return {"status": "ok" if ok else "error"}
