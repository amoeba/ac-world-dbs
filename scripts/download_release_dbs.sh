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
  TAG=$(gh api "repos/$REPO/releases?per_page=100" \
    --jq '.[] | select(.tagName | test("^v[0-9]+$")) | .tagName' \
    | sort -V | tail -n 1)
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
  echo "gh not found; falling back to python json parser"
  python3 -c '
import json, urllib.request, sys, os, basename
url = "https://api.github.com/repos/'"$REPO"'/releases/tags/'"$TAG"'"
with urllib.request.urlopen(url) as r:
    data = json.load(r)
for a in data.get("assets", []):
    n = a.get("name", "")
    if n.endswith(".db") or n.endswith(".sql.zst"):
        out = os.path.join("'"$OUTDIR"'", n)
        print("Downloading " + n + "...")
        urllib.request.urlretrieve(a["browser_download_url"], out)
'
fi

echo "Downloaded databases to $OUTDIR:"
ls -la "$OUTDIR"
