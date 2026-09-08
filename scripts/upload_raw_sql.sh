#!/bin/bash
#
# upload_raw_sql.sh
#
# Create a draft GitHub release and attach a raw MySQL dump file.
# Publishing the draft release triggers the CI workflow that converts the
# dump to SQLite and adds both files to the common 'latest' release.
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
BASENAME="$DB_NAME.sql"

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

echo "Creating draft release $RELEASE_TAG on $REPO..."
gh release create "$RELEASE_TAG" \
  --repo "$REPO" \
  --draft \
  --title "Raw: $DB_NAME" \
  --notes "Raw MySQL dump for $DB_NAME. Publish this release to trigger conversion."

echo "Uploading $FILE as $ASSET_NAME..."
gh release upload "$RELEASE_TAG" "$FILE" \
  --repo "$REPO" \
  --clobber

echo "Publishing release $RELEASE_TAG to trigger conversion..."
gh release edit "$RELEASE_TAG" --repo "$REPO" --draft=false

echo ""
echo "Release published: https://github.com/$REPO/releases/tag/$RELEASE_TAG"
echo "CI will convert the SQL to SQLite and deploy."
