#!/bin/sh
#
# download_release_dbs.sh
#
# Download the latest world databases from the GitHub release.
# Used by Dokku's post_compile hook and for local testing.

set -e

REPO="${RELEASE_REPO:-amoeba/ac-world-dbs}"
TAG="${RELEASE_TAG:-latest}"
OUTDIR="${1:-./databases}"

mkdir -p "$OUTDIR"

echo "Downloading databases from $REPO release $TAG..."

# Prefer gh when available (local dev), otherwise fall back to curl/wget.
if command -v gh >/dev/null 2>&1; then
  gh release download "$TAG" --repo "$REPO" --pattern "*.db" --dir "$OUTDIR"
else
  API_URL="https://api.github.com/repos/$REPO/releases/tags/$TAG"
  echo "gh not found, falling back to curl from $API_URL"
  for asset_url in $(curl -sL "$API_URL" | grep '"browser_download_url":' | grep -E '\.(db|sql\.zst)"' | sed -E 's/.*"([^"]+)".*/\1/'); do
    filename=$(basename "$asset_url")
    echo "Downloading $filename..."
    curl -sL -o "$OUTDIR/$filename" "$asset_url"
  done
fi

echo "Downloaded databases to $OUTDIR:"
ls -la "$OUTDIR"
