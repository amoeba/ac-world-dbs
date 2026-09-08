# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""Build the meta database from the world databases on disk."""

import sqlite3
import tomllib
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "databases"
META_PATH = DB_DIR / "meta.db"
CONFIG_PATH = ROOT / "meta.toml"
RELEASE_REPO = "amoeba/ac-world-dbs"
RELEASE_TAG = "latest"


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


def sqlgz_size(name: str) -> int | None:
    path = DB_DIR / f"{name}.sql.gz"
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
            display_name TEXT,
            world_name TEXT,
            upstream_source TEXT,
            upstream_version TEXT,
            world_variant TEXT,
            world_version TEXT,
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

    for db_path in sorted(DB_DIR.glob("*.db")):
        if db_path.name == "meta.db":
            continue

        name = db_path.stem
        entry = config.get(name, {})
        display_name = entry.get("display_name", name.replace("_", " ").title())
        world_name = entry.get("world_name", "")
        upstream_source = entry.get("upstream_source", "")
        upstream_version = entry.get("upstream_version", "")
        world_variant = entry.get("world_variant", "")
        world_version = entry.get("world_version", "")
        download_url = f"https://github.com/{RELEASE_REPO}/releases/download/{RELEASE_TAG}/{name}.db"
        sql_download_url = f"https://github.com/{RELEASE_REPO}/releases/download/{RELEASE_TAG}/{name}.sql.gz"

        conn = sqlite3.connect(db_path)
        counts = table_counts(conn)
        conn.close()

        table_count = len(counts)
        row_count_total = sum(counts.values())
        file_size = db_path.stat().st_size
        sql_file_size = sqlgz_size(name)
        release_date = datetime.now(timezone.utc).isoformat()

        cur.execute(
            """
            INSERT INTO databases
            (name, display_name, world_name, upstream_source, upstream_version, world_variant, world_version, release_date, download_url, sql_download_url, file_size_bytes, sql_file_size_bytes, table_count, row_count_total, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                name,
                display_name,
                world_name,
                upstream_source,
                upstream_version,
                world_variant,
                world_version,
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


def main() -> None:
    path = build_meta_db()
    print(f"Created {path}")


if __name__ == "__main__":
    main()
