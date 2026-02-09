from __future__ import annotations

from datetime import datetime

from sqlalchemy import Column, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.types import JSON


class Base(DeclarativeBase):
    pass


class Spot(Base):
    __tablename__ = "spots"

    id = Column(String(128), primary_key=True)
    name = Column(String(255), nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    address = Column(String(255), nullable=False)
    summary = Column(Text, nullable=False)
    official_url = Column(String(512))
    cost_range = Column(String(32))
    age_min = Column(Integer)
    age_max = Column(Integer)
    tags = Column(JSON, default=list)
    images = Column(JSON, default=list)
    hours = Column(String(128))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Favorite(Base):
    __tablename__ = "favorites"

    user_id = Column(String(128), primary_key=True)
    spot_id = Column(String(128), primary_key=True)
    created_at = Column(DateTime, default=datetime.utcnow)
