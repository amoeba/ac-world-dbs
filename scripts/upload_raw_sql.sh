#!/bin/bash
#
# upload_raw_sql.sh
#
# Create a GitHub release named raw-<db-name>, attach a zstd-compressed MySQL
# dump file, and publish it. After running this, add an entry to meta.toml and
# push; CI will then convert the dump to SQLite and include it in the next
# versioned common release.
#
# Usage:
#   ./upload_raw_sql.sh <path-to-sql-file> <database-name>
#
#   <database-name> should be the published database name: {server} or
#   {server}-{patch}, lowercased (e.g. dekaru or dekaru-customdm).
#
# Examples:
#   ./upload_raw_sql.sh ~/Downloads/ACE-World-CE16PY-db-v0.7.18-CustomDM-v3.14.sql.7z dekaru-customdm
#   ./upload_raw_sql.sh ~/Downloads/dump.sql dekaru-infiltration

set -e

REPO="${RELEASE_REPO:-amoeba/ac-world-dbs}"
FILE="$1"
DB_NAME="$2"

if [ -z "$FILE" ] || [ -z "$DB_NAME" ]; then
  echo "Usage: $0 <path-to-sql-file> <database-name>"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE"
  exit 1
fi

if ! command -v zstd >/dev/null 2>&1; then
  echo "zstd is required but not installed. Install it and retry."
  exit 1
fi

TMPDIR=$(mktemp -d)
SQL_FILE="$TMPDIR/$DB_NAME.sql"
ZST_FILE="$TMPDIR/$DB_NAME.sql.zst"

# Decompress the input to a plain .sql file if needed.
case "$FILE" in
  *.sql.7z)
    7z e -so "$FILE" > "$SQL_FILE"
    ;;
  *.sql.gz)
    gunzip -c "$FILE" > "$SQL_FILE"
    ;;
  *.sql.zst)
    zstd -dc "$FILE" > "$SQL_FILE"
    ;;
  *.sql)
    cp "$FILE" "$SQL_FILE"
    ;;
  *)
    echo "Unsupported extension: $FILE (expected .sql, .sql.zst, .sql.gz, or .sql.7z)"
    exit 1
    ;;
esac

echo "Compressing with zstd..."
zstd -19 -T0 -o "$ZST_FILE" "$SQL_FILE"

RELEASE_TAG="raw-$DB_NAME"

echo "Creating release $RELEASE_TAG on $REPO..."
gh release create "$RELEASE_TAG" \
  --repo "$REPO" \
  --draft \
  --title "Raw: $DB_NAME" \
  --notes "Raw MySQL dump for $DB_NAME (zstd-compressed)."

echo "Uploading $ZST_FILE..."
gh release upload "$RELEASE_TAG" "$ZST_FILE" \
  --repo "$REPO" \
  --clobber

echo "Publishing release $RELEASE_TAG..."
gh release edit "$RELEASE_TAG" --repo "$REPO" --draft=false

rm -rf "$TMPDIR"

echo ""
echo "Release published: https://github.com/$REPO/releases/tag/$RELEASE_TAG"
echo ""
echo "Add an entry like this to meta.toml, then commit and push:"
echo ""
echo "[$DB_NAME]"
echo 'display_name = ""'
echo 'world_name = ""'
echo 'upstream_source = ""'
echo 'upstream_version = ""'
echo 'world_variant = ""'
echo 'world_version = ""'
