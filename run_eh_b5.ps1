$ErrorActionPreference = "Stop"

Write-Host "Doctor App EH-B5 verification" -ForegroundColor Cyan

flutter pub get

dart format --output=none `
  lib/core/errors `
  lib/core/widgets/app_error_ui.dart `
  lib/features/auth/data/login_error_policy.dart `
  lib/features/sync/services/sync_error_policy.dart `
  test/api_error_classifier_test.dart `
  test/login_error_policy_test.dart `
  test/offline_fallback_policy_test.dart `
  test/sync_error_policy_test.dart `
  test/app_error_ui_model_test.dart `
  test/error_handling_contract_test.dart

flutter analyze --no-fatal-infos --no-fatal-warnings

$tests = @(
  "test/api_error_classifier_test.dart",
  "test/login_error_policy_test.dart",
  "test/offline_fallback_policy_test.dart",
  "test/sync_error_policy_test.dart",
  "test/app_error_ui_model_test.dart",
  "test/error_handling_contract_test.dart"
)

foreach ($test in $tests) {
  flutter test $test
}

flutter build apk --debug

Write-Host "EH-B5 automated verification passed." -ForegroundColor Green
