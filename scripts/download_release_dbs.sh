#!/bin/sh
#
# download_release_dbs.sh
#
# Download the latest world databases from the GitHub release.
# Used by Dokku's post_compile hook and for local testing.
#
# The repo only publishes versioned releases (v1, v2, ...); there is no
# release literally tagged "latest". So when RELEASE_TAG is the special
# token "latest", resolve it to the newest versioned release before
# downloading.

set -e

REPO="${RELEASE_REPO:-amoeba/ac-world-dbs}"
TAG="${RELEASE_TAG:-latest}"
OUTDIR="${1:-./databases}"

mkdir -p "$OUTDIR"

echo "Downloading databases from $REPO release $TAG..."

# Map the special "latest" token to the newest versioned common release
# (v1, v2, ...). Raw dump releases (raw-*) are excluded so they can never
# hijack the deploy.
if [ "$TAG" = "latest" ]; then
  echo "Resolving newest common release for $REPO..."
  TAG=$(curl -sL "https://api.github.com/repos/$REPO/releases?per_page=100" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
    | grep -E '^v[0-9]+$' \
    | sort -V \
    | tail -n 1)
  if [ -z "$TAG" ]; then
    echo "Could not resolve newest common release; aborting." >&2
    exit 1
  fi
fi

echo "Using release tag: $TAG"

# Prefer gh when available (local dev), otherwise fall back to curl/wget.
if command -v gh >/dev/null 2>&1; then
  gh release download "$TAG" --repo "$REPO" --pattern "*.db" --pattern "*.sql.zst" --dir "$OUTDIR"
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
