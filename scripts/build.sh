#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NODE_BIN="$(command -v node)"
NODE_MAJOR="$("$NODE_BIN" -p "process.versions.node.split('.')[0]")"
if [[ "$NODE_MAJOR" -lt 22 ]]; then
  echo "Node.js v22+ is required for this SEA pipeline (found v$NODE_MAJOR)." >&2
  exit 1
fi

POSTJECT_BIN="$ROOT_DIR/node_modules/.bin/postject"
if [[ ! -x "$POSTJECT_BIN" ]]; then
  echo "Missing postject binary at $POSTJECT_BIN. Run npm install first." >&2
  exit 1
fi

mkdir -p dist

echo "1/5 Bundling source..."
npm run build:bundle

echo "2/5 Generating SEA prep blob..."
"$NODE_BIN" --experimental-sea-config sea-config.json

echo "3/5 Creating executable from node runtime..."
cp "$NODE_BIN" demo-cli

echo "4/5 Injecting SEA blob..."
if [[ "$(uname -s)" == "Darwin" ]]; then
  codesign --remove-signature demo-cli || true
  "$POSTJECT_BIN" demo-cli NODE_SEA_BLOB dist/sea-prep.blob \
    --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2 \
    --macho-segment-name NODE_SEA
else
  "$POSTJECT_BIN" demo-cli NODE_SEA_BLOB dist/sea-prep.blob \
    --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
fi

echo "5/5 Codesigning executable..."
if [[ "$(uname -s)" == "Darwin" ]]; then
  codesign --sign - --force demo-cli
fi

chmod +x demo-cli
echo "Build complete: $ROOT_DIR/demo-cli"
