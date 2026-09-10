# ac-world-dbs

A Datasette instance hosting world databases for Asheron's Call, plus a meta database describing each one.

## Structure

- `databases/` — SQLite databases served by Datasette (populated from GitHub releases; not committed).
  - `meta.db` — Metadata about each world database.
  - `dekaru-customdm.db` — Dekaru (CustomDM patch) world database.
  - `dekaru-infiltration.db` — Dekaru (Infiltration patch) world database.
- `meta.toml` — Configuration describing each world database. Each section is keyed by the published database name and has `server` and `patch` fields; the name is derived as `{server}` or `{server}-{patch}` (lowercased).
- `db-to-sqlite` is installed from `amoeba/db-to-sqlite` (fork of `simonw/db-to-sqlite`) because the fork applies a `byteorder="big"` fix in `cli.py` (`int.from_bytes`) required for correct MySQL conversion.
- `scripts/` — Scripts to upload raw MySQL dumps, convert them to SQLite, build the meta database, and download release assets.
- Rebuild logic — `build-and-release.yml` caches conversions via `manifest.json`; a DB is rebuilt only if its raw asset `raw_size` changes or its `.db` is missing. Otherwise the cached `.db` is reused.
- `bin/post_compile` — Dokku hook to fetch databases from the latest GitHub release before startup.

## Adding a new world database

1. Obtain the raw MySQL dump (`.sql`, `.sql.gz`, `.sql.zst`, or `.sql.7z`) for the world.
2. Upload it as a `raw-<database-name>` release, where `database-name` is `{server}` or `{server}-{patch}` (lowercased):

   ```sh
   ./scripts/upload_raw_sql.sh ~/Downloads/ACE-World-....sql.7z <database-name>
   ```

3. Add a section to `meta.toml` with `server` and `patch` fields (plus optional `patch_version`, `display_name`, `upstream_source`, `upstream_version`), then commit and push to `main`. (Or use `./scripts/upload_raw_sql.sh`; it reads `scripts/meta_entry.template.toml` so the emitted keys stay in sync with `meta.toml`.) CI derives the database name from `server`/`patch`, converts the dump to SQLite, publishes it in the next versioned release, and redeploys.

## Running locally

```sh
uv sync
sh scripts/download_release_dbs.sh ./databases
uv run scripts/build_meta_db.py
datasette .
```

## Deployment

Pushes to `main` trigger a GitHub Actions workflow that:

1. Converts all databases configured in `meta.toml` from their `raw-<name>` releases to SQLite.
2. Builds the meta database.
3. Publishes the databases as assets on a new auto-incremented versioned release (`v1`, `v2`, ...).
4. Deploys the Datasette app to Dokku.

Dokku downloads the newest versioned release's databases via `bin/post_compile` before starting the app. The script resolves "latest" to the newest release tagged `v[0-9]+` through the GitHub API — there is no release literally tagged `latest`, and raw dump releases (`raw-*`) are excluded.
