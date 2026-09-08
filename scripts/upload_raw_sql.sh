#!/bin/bash
#
# upload_raw_sql.sh
#
# Create the next versioned GitHub release, attach a raw MySQL dump file,
# and publish it. The CI workflow triggers on the published release, converts
# the dump to SQLite, and adds both the compressed raw SQL and the SQLite
# database to the same versioned release.
#
# Usage:
#   ./upload_raw_sql.sh <path-to-sql-file> <database-name>
#
# Examples:
#   ./upload_raw_sql.sh ~/Downloads/ACE-World-CE16PY-db-v0.7.18-CustomDM-v3.14.sql.7z ace_world_customdm
#   ./upload_raw_sql.sh ~/Downloads/dump.sql ace_world_patches

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

EXT="${FILE##*.}"

# Normalize the uploaded asset name so CI can find it.
case "$EXT" in
  7z)
    ASSET_NAME="$DB_NAME.sql.7z"
    ;;
  gz)
    ASSET_NAME="$DB_NAME.sql.gz"
    ;;
  sql)
    ASSET_NAME="$DB_NAME.sql"
    ;;
  *)
    echo "Unsupported extension: $EXT (expected .sql, .sql.gz, or .sql.7z)"
    exit 1
    ;;
esac

# Find the latest vN release and compute the next version.
LATEST=$(gh release list --repo "$REPO" --limit 50 --json tagName -q '.[].tagName' | grep -E '^v[0-9]+$' | sort -V | tail -n 1 || true)
if [ -z "$LATEST" ]; then
  NEXT_TAG="v1"
else
  NEXT_NUM=$(echo "$LATEST" | sed 's/^v//')
  NEXT_TAG="v$((NEXT_NUM + 1))"
fi

echo "Creating release $NEXT_TAG on $REPO..."
gh release create "$NEXT_TAG" \
  --repo "$REPO" \
  --draft \
  --title "$NEXT_TAG" \
  --notes "Raw MySQL dump for $DB_NAME."

echo "Uploading $FILE as $ASSET_NAME..."
TMPDIR=$(mktemp -d)
cp "$FILE" "$TMPDIR/$ASSET_NAME"
gh release upload "$NEXT_TAG" "$TMPDIR/$ASSET_NAME" \
  --repo "$REPO" \
  --clobber
rm -rf "$TMPDIR"

echo "Publishing release $NEXT_TAG to trigger conversion and deployment..."
gh release edit "$NEXT_TAG" --repo "$REPO" --draft=false

echo ""
echo "Release published: https://github.com/$REPO/releases/tag/$NEXT_TAG"
echo "CI will convert the SQL to SQLite, add existing assets, and deploy."
