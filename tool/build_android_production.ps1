param([Parameter(Mandatory=$true)][string]$ApiUrl)
$ErrorActionPreference = 'Stop'
if (-not $ApiUrl.StartsWith('https://')) {
  throw 'Production API URL must use HTTPS.'
}
flutter build appbundle --release --flavor pp -t lib/main.dart `
  --dart-define=PP_CLOUD_API_URL=$ApiUrl `
  --dart-define=PP_ALLOW_INSECURE_HTTP=false

if ($LASTEXITCODE -ne 0) { throw "Flutter build failed." }
