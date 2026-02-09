# Family Outings Backend

## Run (dev)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Notes
- Replace mock routes with DB integration (PostgreSQL + PostGIS)
- Add auth verification for Apple/Google
- Add pagination and search indexing
