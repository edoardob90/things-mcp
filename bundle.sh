#!/bin/bash
# Build a .mcpb bundle that runs this fork at the current, pushed commit.
# Upstream's manifest.json is the base; manifest.custom.json overrides name,
# description and author. The bundle holds no code: Claude Desktop runs
# `uvx --from git+<fork>@<sha> things-mcp`, so it always runs exactly <sha>.
set -euo pipefail
cd "$(dirname "$0")"

REPO="https://github.com/edoardob90/things-mcp"
MCPB="npx -y @anthropic-ai/mcpb@2.1.2"

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
    echo "Uncommitted changes: commit and push first." >&2; exit 1
fi
SHA=$(git rev-parse HEAD)
git fetch -q origin
if [ -z "$(git branch -r --contains "$SHA" --list 'origin/*')" ]; then
    echo "$SHA is not on origin: push first." >&2; exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

jq -s --arg src "git+$REPO@$SHA" '
    (.[0] * .[1]) + {author: .[1].author}
    | .server.mcp_config.args = ["--from", $src, "things-mcp"]
' manifest.json manifest.custom.json > "$TMP/manifest.json"
mkdir -p "$TMP/server"
echo "# Stub: the server is fetched by uvx from $REPO@$SHA" > "$TMP/server/stub.py"

NAME=$(jq -r .name "$TMP/manifest.json")
VERSION=$(jq -r .version "$TMP/manifest.json")
OUT="dist/$NAME-$VERSION+${SHA:0:7}.mcpb"
mkdir -p dist
$MCPB validate "$TMP/manifest.json"
$MCPB pack "$TMP" "$OUT"
echo "Built $OUT (runs $SHA)"
