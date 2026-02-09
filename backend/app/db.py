from __future__ import annotations

import os
from contextlib import contextmanager

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app import models


DATABASE_URL = os.getenv("DATABASE_URL", "")


def _default_sqlite_url() -> str:
    return "sqlite:///./family_outings.db"


def _build_engine_url() -> str:
    if DATABASE_URL:
        return DATABASE_URL
    return _default_sqlite_url()


engine = create_engine(_build_engine_url(), pool_pre_ping=True, future=True)


@contextmanager
def session_scope() -> Session:
    session = Session(bind=engine)
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def init_db() -> None:
    models.Base.metadata.create_all(bind=engine)
