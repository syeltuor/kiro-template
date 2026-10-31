#!/usr/bin/env bash
# kiro-template v2.0.0
#
# Render staging/favicon.svg to the PWA icon set. Headless Chrome renders it once at
# 512x512 with a transparent background (Chrome has a minimum window size, so small sizes
# can't be rendered directly), then `sips -z` derives 16/32/48/96/128/192 and the 180
# apple-touch icon; make-ico.py packs 16/32/48 into favicon.ico. macOS only (sips).
#
# Usage: scripts/make-icons.sh
set -euo pipefail
[ $# -eq 0 ] || { echo "Usage: $0" >&2; exit 2; }
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SITE_DIR="${SITE_DIR:-staging}"
SITE="$ROOT/$SITE_DIR"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
[ -x "$CHROME" ] || { echo "❌ Chrome not found at $CHROME (set CHROME=...)" >&2; exit 1; }
command -v sips >/dev/null || { echo "❌ sips not found (macOS only)" >&2; exit 1; }
[ -f "$SITE/favicon.svg" ] || { echo "❌ $SITE_DIR/favicon.svg missing" >&2; exit 1; }
TMP=$(mktemp -d "${TMPDIR:-/tmp}/icons.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
cp "$SITE/favicon.svg" "$TMP/favicon.svg"
cat > "$TMP/wrap.html" <<'HTML'
<!doctype html>
<html><head><meta charset="utf-8">
<style>html,body{margin:0;padding:0;background:transparent;overflow:hidden}img{display:block;width:512px;height:512px}</style>
</head><body><img src="favicon.svg" alt=""></body></html>
HTML
"$CHROME" --headless --disable-gpu --hide-scrollbars --no-first-run --no-default-browser-check \
  --user-data-dir="$TMP/profile" --default-background-color=00000000 --window-size=512,512 \
  --screenshot="$TMP/icon-512.png" "file://$TMP/wrap.html" >/dev/null 2>&1
dims() { sips -g pixelWidth -g pixelHeight "$1" | awk '/pixel(Width|Height)/{printf "%s ", $2}'; }
[ "$(dims "$TMP/icon-512.png")" = "512 512 " ] || { echo "❌ Chrome render is $(dims "$TMP/icon-512.png"), expected 512 512" >&2; exit 1; }
mkdir -p "$SITE/icons"
cp "$TMP/icon-512.png" "$SITE/icons/icon-512.png"
for n in 16 32 48 96 128 192; do
  sips -z "$n" "$n" "$TMP/icon-512.png" --out "$SITE/icons/icon-$n.png" >/dev/null
done
sips -z 180 180 "$TMP/icon-512.png" --out "$SITE/apple-touch-icon.png" >/dev/null
python3 "$ROOT/scripts/make-ico.py" "$SITE/favicon.ico" \
  "$SITE/icons/icon-16.png" "$SITE/icons/icon-32.png" "$SITE/icons/icon-48.png"
echo "✅ icons written to $SITE_DIR/icons/, $SITE_DIR/apple-touch-icon.png, $SITE_DIR/favicon.ico"
