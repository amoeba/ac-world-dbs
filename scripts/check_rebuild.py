#!/usr/bin/env python3
"""Local rebuild-check: which DBs need rebuild vs can use cache."""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "databases"

def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")

def db_name_from_config(entry: dict) -> str:
    server = slugify(entry.get("server", ""))
    patch = slugify(entry.get("patch", ""))
    if not server:
        raise ValueError("missing server")
    return f"{server}-{patch}" if patch else server

import tomllib
with open(ROOT / "meta.toml", "rb") as f:
    config = tomllib.load(f)

manifest = {}
manifest_path = DB_DIR / "manifest.json"
if manifest_path.exists():
    manifest = json.load(open(manifest_path))

for section, entry in config.items():
    name = db_name_from_config(entry)
    db_file = DB_DIR / f"{name}.db"
    cached = manifest.get(name, {}).get("raw_size")
    status = "cached (db exists)" if db_file.exists() else "NEEDS REBUILD (db missing)"
    print(f"{name}: {status}  manifest_raw_size={cached}")
