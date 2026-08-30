#!/usr/bin/env bash
set -euo pipefail
api_url="${1:?Usage: build_ios_production.sh https://api.example.com/api}"
case "$api_url" in
  https://*) ;;
  *) echo 'Production API URL must use HTTPS.' >&2; exit 1 ;;
esac
/usr/libexec/PlistBuddy -c 'Set :NSAppTransportSecurity:NSAllowsArbitraryLoads false' ios/Runner/Info.plist
flutter build ipa --release \
  --dart-define=PP_CLOUD_API_URL="$api_url" \
  --dart-define=PP_ALLOW_INSECURE_HTTP=false
