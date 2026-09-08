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
gh release download "$TAG" --repo "$REPO" --pattern "*.db" --dir "$OUTDIR" || {
  echo "Failed to download release databases. If running locally, ensure gh is authenticated."
  exit 1
}

echo "Downloaded databases to $OUTDIR:"
ls -la "$OUTDIR"
