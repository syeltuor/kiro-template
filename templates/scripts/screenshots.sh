#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Desktop and mobile screenshots of the local site (staging/ served on localhost) with
# headless Chrome. Mobile shots go through cdp-shot.mjs because headless Chrome clamps
# --window-size to a ~500 px minimum width.
#
# Usage: scripts/screenshots.sh [outdir] [name=path ...]
#   outdir defaults to build/screenshots; pages default to home=/
#   e.g. scripts/screenshots.sh build/screenshots home=/ about=/about.html "app=/?mock=1#/overview"
#
# Env: CHROME (path), DESKTOP=1440x2000, MOBILE=390x1800, PORT=8765, SITE_DIR=staging
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/build/screenshots"
if [ $# -ge 1 ] && [[ "$1" != *=* ]]; then OUT="$1"; shift; fi
PAGES=("$@")
[ ${#PAGES[@]} -gt 0 ] || PAGES=("home=/")

PORT="${PORT:-8765}"
DESKTOP="${DESKTOP:-1440x2000}"
MOBILE="${MOBILE:-390x1800}"
SITE_DIR="${SITE_DIR:-staging}"
BASE="http://localhost:$PORT"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[ -x "$CHROME" ] || { echo "❌ Chrome not found at $CHROME (set CHROME=...)" >&2; exit 1; }
command -v node >/dev/null || { echo "❌ node is required for mobile shots" >&2; exit 1; }
[ -f "$ROOT/$SITE_DIR/index.html" ] || { echo "❌ $SITE_DIR/index.html missing" >&2; exit 1; }
for p in "${PAGES[@]}"; do
  [[ "$p" =~ ^[a-z0-9-]+=/ ]] || { echo "❌ page must look like name=/path, got: $p" >&2; exit 2; }
done
if curl -s -o /dev/null "$BASE/" 2>/dev/null; then
  echo "❌ port $PORT is already in use; stop the other server first" >&2
  exit 1
fi

mkdir -p "$OUT"
PROFILE=$(mktemp -d "${TMPDIR:-/tmp}/shots.XXXXXX")
python3 -m http.server "$PORT" --bind 127.0.0.1 -d "$ROOT/$SITE_DIR" >/dev/null 2>&1 &
SERVER=$!
trap 'kill "$SERVER" 2>/dev/null || true; wait "$SERVER" 2>/dev/null || true; rm -rf "$PROFILE"' EXIT
for _ in $(seq 1 50); do
  curl -s -o /dev/null "$BASE/index.html" && break
  sleep 0.1
done

shot() { # name WxH url
  "$CHROME" --headless --disable-gpu --hide-scrollbars --no-first-run --no-default-browser-check \
    --user-data-dir="$PROFILE" --virtual-time-budget=4000 --window-size="${2/x/,}" \
    --screenshot="$OUT/$1.png" "$3" >/dev/null 2>&1
  [ -s "$OUT/$1.png" ] || { echo "❌ $1.png not written" >&2; exit 1; }
  echo "📸 $OUT/$1.png"
}
mshot() { # name WxH url
  CHROME="$CHROME" node "$ROOT/scripts/cdp-shot.mjs" "$OUT/$1.png" "$3" "${2%x*}" "${2#*x}"
  [ -s "$OUT/$1.png" ] || { echo "❌ $1.png not written" >&2; exit 1; }
  echo "📸 $OUT/$1.png"
}

n=0
for p in "${PAGES[@]}"; do
  name="${p%%=*}"; path="${p#*=}"
  shot "$name-desktop" "$DESKTOP" "$BASE$path"
  mshot "$name-mobile" "$MOBILE" "$BASE$path"
  n=$((n + 2))
done
echo "✅ $n screenshots in $OUT"
