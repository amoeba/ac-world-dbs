# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""Build the meta database from the world databases on disk.

Database names are derived from the `server` and `patch` fields in
meta.toml: `{server}` or `{server}-{patch}`, both lowercased.
"""

import os
import re
import sqlite3
import tomllib
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "databases"
META_PATH = DB_DIR / "meta.db"
CONFIG_PATH = ROOT / "meta.toml"
RELEASE_REPO = "amoeba/ac-world-dbs"
# CI sets this to the concrete versioned release tag (e.g. "v4") so that the
# download URLs in meta.db point at a real release. Falls back to the special
# "latest" token for local dev.
RELEASE_TAG = os.environ.get("RELEASE_TAG", "latest")


def slugify(value: str) -> str:
    """Lowercase a name for use as a database filename component."""
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def db_name_from_config(entry: dict) -> str:
    """Derive the published database name from server/patch fields."""
    server = slugify(entry.get("server", ""))
    patch = slugify(entry.get("patch", ""))
    if not server:
        raise ValueError(f"config entry is missing a 'server' field: {entry}")
    if patch:
        return f"{server}-{patch}"
    return server


def db_display_name(entry: dict) -> str:
    parts = [p for p in (entry.get("server"), entry.get("patch")) if p]
    return entry.get("display_name") or " ".join(parts)


def table_counts(conn: sqlite3.Connection) -> dict[str, int]:
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cur.fetchall()]
    counts: dict[str, int] = {}
    for table in tables:
        try:
            cur.execute(f"SELECT COUNT(*) FROM [{table}]")
            counts[table] = cur.fetchone()[0]
        except sqlite3.Error:
            counts[table] = -1
    return counts


def sqlzst_size(name: str) -> int | None:
    path = DB_DIR / f"{name}.sql.zst"
    if path.exists():
        return path.stat().st_size
    return None


def build_meta_db() -> Path:
    DB_DIR.mkdir(exist_ok=True)
    META_PATH.unlink(missing_ok=True)

    meta = sqlite3.connect(META_PATH)
    cur = meta.cursor()

    cur.execute(
        """
        CREATE TABLE databases (
            name TEXT PRIMARY KEY,
            server TEXT,
            patch TEXT,
            patch_version TEXT,
            display_name TEXT,
            upstream_source TEXT,
            upstream_version TEXT,
            release_date TEXT,
            download_url TEXT,
            sql_download_url TEXT,
            file_size_bytes INTEGER,
            sql_file_size_bytes INTEGER,
            table_count INTEGER,
            row_count_total INTEGER,
            created_at TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE tables (
            database_name TEXT,
            table_name TEXT,
            row_count INTEGER,
            PRIMARY KEY (database_name, table_name)
        )
        """
    )

    config: dict[str, dict] = {}
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, "rb") as f:
            config = tomllib.load(f)

    for section, entry in config.items():
        name = db_name_from_config(entry)
        server = entry.get("server", "")
        patch = entry.get("patch", "")
        display_name = db_display_name(entry)
        upstream_source = entry.get("upstream_source", "")
        upstream_version = entry.get("upstream_version", "")
        patch_version = entry.get("patch_version", "")
        download_url = f"https://github.com/{RELEASE_REPO}/releases/download/{RELEASE_TAG}/{name}.db"
        sql_download_url = f"https://github.com/{RELEASE_REPO}/releases/download/{RELEASE_TAG}/{name}.sql.zst"

        db_path = DB_DIR / f"{name}.db"
        if not db_path.exists():
            print(f"WARNING: {db_path} not found; skipping {section}")
            continue

        conn = sqlite3.connect(db_path)
        counts = table_counts(conn)
        conn.close()

        table_count = len(counts)
        row_count_total = sum(counts.values())
        file_size = db_path.stat().st_size
        sql_file_size = sqlzst_size(name)
        release_date = datetime.now(timezone.utc).isoformat()

        cur.execute(
            """
            INSERT INTO databases
            (name, server, patch, patch_version, display_name, upstream_source, upstream_version, release_date, download_url, sql_download_url, file_size_bytes, sql_file_size_bytes, table_count, row_count_total, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                name,
                server,
                patch,
                patch_version,
                display_name,
                upstream_source,
                upstream_version,
                release_date,
                download_url,
                sql_download_url,
                file_size,
                sql_file_size,
                table_count,
                row_count_total,
                release_date,
            ),
        )

        for table_name, row_count in counts.items():
            cur.execute(
                "INSERT INTO tables VALUES (?, ?, ?)",
                (name, table_name, row_count),
            )

    meta.commit()
    meta.close()
    return META_PATH


def validate_sync(meta_path: Path, config_path: Path) -> None:
    import tomllib
    with open(config_path, "rb") as f:
        config = tomllib.load(f)
    import sqlite3
    conn = sqlite3.connect(str(meta_path))
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='databases'")
    if cur.fetchone() is None:
        raise RuntimeError("meta.db missing 'databases' table")
    cur.execute("SELECT name FROM databases")
    dbs = {row[0] for row in cur.fetchall()}
    for section, entry in config.items():
        expected = db_name_from_config(entry)
        if expected not in dbs:
            raise RuntimeError(f"meta.db missing {expected} (from meta.toml [{section}])")
    print("meta.db sync validated against meta.toml")
    conn.close()


def main() -> None:
    path = build_meta_db()
    print(f"Created {path}")
    validate_sync(path, CONFIG_PATH)


if __name__ == "__main__":
    main()