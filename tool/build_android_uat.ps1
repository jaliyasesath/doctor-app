$ErrorActionPreference = 'Stop'
flutter build apk --debug --flavor pp -t lib/main.dart `
  --dart-define=PP_CLOUD_API_URL=http://169.58.40.160/api `
  --dart-define=PP_ALLOW_INSECURE_HTTP=true

if ($LASTEXITCODE -ne 0) { throw "Flutter build failed." }
