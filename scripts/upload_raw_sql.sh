#!/bin/bash
#
# upload_raw_sql.sh
#
# Create a GitHub release named raw-<db-name>, attach a raw MySQL dump file,
# and publish it. After running this, add an entry to meta.toml and push;
# CI will then convert the dump to SQLite and include it in the next versioned
# common release.
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

RELEASE_TAG="raw-$DB_NAME"

echo "Creating release $RELEASE_TAG on $REPO..."
gh release create "$RELEASE_TAG" \
  --repo "$REPO" \
  --draft \
  --title "Raw: $DB_NAME" \
  --notes "Raw MySQL dump for $DB_NAME."

echo "Uploading $FILE as $ASSET_NAME..."
TMPDIR=$(mktemp -d)
cp "$FILE" "$TMPDIR/$ASSET_NAME"
gh release upload "$RELEASE_TAG" "$TMPDIR/$ASSET_NAME" \
  --repo "$REPO" \
  --clobber
rm -rf "$TMPDIR"

echo "Publishing release $RELEASE_TAG..."
gh release edit "$RELEASE_TAG" --repo "$REPO" --draft=false

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
