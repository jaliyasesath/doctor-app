#!/usr/bin/env bash
set -euo pipefail
plist="ios/Runner/Info.plist"
backup="${plist}.production-backup"
cp "$plist" "$backup"
trap 'mv "$backup" "$plist"' EXIT
/usr/libexec/PlistBuddy -c 'Set :NSAppTransportSecurity:NSAllowsArbitraryLoads true' "$plist"
flutter build ipa --release \
  --dart-define=PP_CLOUD_API_URL=http://169.58.40.160/api \
  --dart-define=PP_ALLOW_INSECURE_HTTP=true
