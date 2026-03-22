#!/usr/bin/env bash
# Kopiert das Xcode-App-Icon-Export nach docs/assets/app-icon-1024.png und erzeugt Favicons.
# Quelle: In Xcode / Asset Catalog das 1024×1024-Icon exportieren und hier ablegen.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="$ROOT/docs/assets"
SOURCE="$OUT_DIR/MunichCommuterIcon-iOS-Default-1024x1024@1x.png"

if [[ ! -f "$SOURCE" ]]; then
  echo "Fehlend: $SOURCE" >&2
  echo "Bitte das 1024×1024 App-Icon aus Xcode nach docs/assets/ exportieren (Dateiname wie oben)." >&2
  exit 1
fi

cp "$SOURCE" "$OUT_DIR/app-icon-1024.png"
cd "$OUT_DIR"
sips -z 16 16 app-icon-1024.png --out favicon-16.png >/dev/null
sips -z 32 32 app-icon-1024.png --out favicon-32.png >/dev/null
sips -z 48 48 app-icon-1024.png --out favicon-48.png >/dev/null
sips -z 180 180 app-icon-1024.png --out apple-touch-icon.png >/dev/null
echo "OK: app-icon-1024.png + Favicons aus $(basename "$SOURCE")"
