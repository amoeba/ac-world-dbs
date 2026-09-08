# ac-world-dbs

A Datasette instance hosting world databases for Asheron's Call, plus a meta database describing each one.

## Structure

- `databases/` — SQLite databases served by Datasette.
  - `meta.db` — Metadata about each world database.
  - `test_world_fauna.db` — Sample fauna and spawn data.
  - `test_world_landmarks.db` — Sample landmarks and regions.
- `databases.toml` — Configuration describing each world database.
- `scripts/` — Scripts to create test data, build the meta database, and download release assets.
- `bin/post_compile` — Dokku hook to fetch databases from the latest GitHub release before startup.

## Running locally

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python scripts/create_test_dbs.py
python scripts/build_meta_db.py
datasette .
```

## Deployment

Pushes to `main` trigger a GitHub Actions workflow that:

1. Builds the test databases and meta database.
2. Publishes them as assets on the `latest` GitHub release.
3. Deploys the Datasette app to Dokku.

Dokku downloads the latest databases via `bin/post_compile` before starting the app.
