"""Daily batch pipeline (skeleton).

Steps:
1) Fetch from official sources + approved APIs
2) Normalize/clean fields
3) Geocode addresses to lat/lng
4) De-duplicate
5) Upsert into DB (placeholder)
"""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Iterable, List, Optional


@dataclass
class SpotRecord:
    id: str
    name: str
    address: str
    summary: str
    lat: Optional[float]
    lng: Optional[float]
    official_url: Optional[str]
    cost_range: Optional[str]
    age_min: Optional[int]
    age_max: Optional[int]
    tags: List[str]
    images: List[str]
    hours: Optional[str]
    source: str
    last_seen: str


class Source:
    name: str = "source"

    def fetch(self) -> Iterable[dict]:
        raise NotImplementedError


class LocalSampleSource(Source):
    name = "local-sample"

    def fetch(self) -> Iterable[dict]:
        return [
            {
                "id": "sample-park-1",
                "name": "Sample Park",
                "address": "Chiyoda-ku, Tokyo",
                "summary": "Playground and sandbox.",
                "lat": 35.6895,
                "lng": 139.6917,
                "official_url": None,
                "cost_range": "FREE",
                "age_min": 0,
                "age_max": 8,
                "tags": ["屋外", "ベビーカーOK"],
                "images": [],
                "hours": "9:00-17:00",
            }
        ]


def normalize_cost_range(value: Optional[str]) -> Optional[str]:
    if not value:
        return None
    value = value.upper()
    allowed = {"FREE", "U500", "U1000", "U3000", "OVER3000"}
    return value if value in allowed else None


def normalize_tags(tags: Iterable[str]) -> List[str]:
    return sorted({t.strip() for t in tags if t.strip()})


def normalize_record(raw: dict, source: str) -> SpotRecord:
    now = datetime.utcnow().isoformat() + "Z"
    return SpotRecord(
        id=raw.get("id") or f"{source}:{raw.get('name','unknown')}",
        name=raw.get("name", ""),
        address=raw.get("address", ""),
        summary=raw.get("summary", ""),
        lat=raw.get("lat"),
        lng=raw.get("lng"),
        official_url=raw.get("official_url"),
        cost_range=normalize_cost_range(raw.get("cost_range")),
        age_min=raw.get("age_min"),
        age_max=raw.get("age_max"),
        tags=normalize_tags(raw.get("tags", [])),
        images=raw.get("images", []),
        hours=raw.get("hours"),
        source=source,
        last_seen=now,
    )


def dedupe(records: Iterable[SpotRecord]) -> List[SpotRecord]:
    seen = set()
    result: List[SpotRecord] = []
    for record in records:
        key = (record.name.strip().lower(), record.address.strip().lower())
        if key in seen:
            continue
        seen.add(key)
        result.append(record)
    return result


def upsert_to_db(records: Iterable[SpotRecord]) -> None:
    # TODO: Replace with real DB upsert (PostgreSQL + PostGIS).
    # For now we just print summary stats.
    records = list(records)
    print(f"Upsert placeholder: {len(records)} records")


def write_output(records: Iterable[SpotRecord], output_path: str) -> None:
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    payload = [asdict(r) for r in records]
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def run(sources: Iterable[Source], output_path: str) -> None:
    normalized: List[SpotRecord] = []
    for source in sources:
        for raw in source.fetch():
            normalized.append(normalize_record(raw, source.name))

    deduped = dedupe(normalized)
    upsert_to_db(deduped)
    write_output(deduped, output_path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        default=os.path.join(os.path.dirname(__file__), "output", "spots.json"),
    )
    args = parser.parse_args()

    sources: List[Source] = [LocalSampleSource()]
    run(sources, args.output)


if __name__ == "__main__":
    main()
