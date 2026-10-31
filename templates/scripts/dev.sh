#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Serve staging/ locally (static files only, no AWS). Use a mock/fixture mode in the
# app (e.g. ?mock=1 on localhost) so the UI works without the API or a sign-in.
#
# Usage: scripts/dev.sh [port]     (default 8765)
set -euo pipefail
[ $# -le 1 ] || { echo "Usage: $0 [port]" >&2; exit 2; }
PORT="${1:-8765}"
[[ "$PORT" =~ ^[0-9]{2,5}$ ]] || { echo "❌ port must be a number" >&2; exit 2; }
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SITE_DIR="${SITE_DIR:-staging}"
[ -f "$ROOT/$SITE_DIR/index.html" ] || { echo "❌ $SITE_DIR/index.html missing" >&2; exit 1; }
echo "🌐 http://localhost:$PORT/  (Ctrl-C to stop)"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 -d "$ROOT/$SITE_DIR"
