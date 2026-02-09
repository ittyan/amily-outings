# Family Outings Architecture

## iOS
- SwiftUI + MapKit + CoreLocation
- MVVM-ish (View + service objects)
- Apple Sign In (required by App Store if any other sign-in is offered)

## Backend
- FastAPI
- PostgreSQL + PostGIS
- Search: MeiliSearch or Postgres full-text

## Batch
- Daily cron
- Official sources + approved APIs
- Normalize + dedupe + upsert
