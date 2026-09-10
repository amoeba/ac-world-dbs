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
#
# Prefer gh (local dev), but Dokku's build container doesn't ship gh, so
# fall back to python3. python3 is guaranteed on PATH here because this
# app is built with the Python buildpack before bin/post_compile runs.
if [ "$TAG" = "latest" ]; then
  echo "Resolving newest common release for $REPO..."
  if command -v gh >/dev/null 2>&1; then
    TAG=$(gh api "repos/$REPO/releases?per_page=100" \
      --jq '.[] | select(.tag_name | test("^v[0-9]+$")) | .tag_name' \
      | sort -V | tail -n 1)
  else
    TAG=$(python3 - "$REPO" <<'PY'
import json
import re
import sys
import urllib.request

repo = sys.argv[1]
url = f"https://api.github.com/repos/{repo}/releases?per_page=100"
with urllib.request.urlopen(url) as r:
    releases = json.load(r)
versions = sorted(
    int(r["tag_name"][1:])
    for r in releases
    if re.match(r"^v[0-9]+$", r["tag_name"])
)
print(f"v{versions[-1]}" if versions else "")
PY
)
  fi
  if [ -z "$TAG" ]; then
    echo "Could not resolve newest common release; aborting." >&2
    exit 1
  fi
fi

echo "Using release tag: $TAG"

# Prefer gh when available (local dev), otherwise fall back to python3.
# Dokku's build container uses the python3 path.
if command -v gh >/dev/null 2>&1; then
  gh release download "$TAG" --repo "$REPO" --pattern "*.db" --pattern "*.sql.zst" --dir "$OUTDIR"
else
  echo "gh not found; falling back to python3"
  python3 - "$REPO" "$TAG" "$OUTDIR" <<'PY'
import json
import os
import sys
import urllib.request

repo, tag, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
url = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
with urllib.request.urlopen(url) as r:
    release = json.load(r)
for asset in release.get("assets", []):
    name = asset.get("name", "")
    if name.endswith(".db") or name.endswith(".sql.zst"):
        dest = os.path.join(outdir, name)
        print(f"Downloading {name}...")
        urllib.request.urlretrieve(asset["browser_download_url"], dest)
PY
fi

echo "Downloaded databases to $OUTDIR:"
ls -la "$OUTDIR"