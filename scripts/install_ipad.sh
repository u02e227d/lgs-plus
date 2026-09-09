#!/usr/bin/env bash
# iPad へ Release を上書きインストール（アンインストールしない＝現場・図面・比例尺を保持）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${1:-00008101-001038992679A01E}"
cd "$ROOT"

echo "==> flutter build ios --release"
flutter build ios --release

APP="$ROOT/build/ios/iphoneos/Runner.app"
if [[ ! -d "$APP" ]]; then
  echo "Runner.app が見つかりません: $APP" >&2
  exit 1
fi

echo "==> 上書きインストール（データ保持）→ $DEVICE_ID"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
echo "==> 完了。ホームから LGS+ を起動してください（現場データは消えません）。"
