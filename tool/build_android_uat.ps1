$ErrorActionPreference = 'Stop'
flutter build apk --debug `
  --dart-define=PP_CLOUD_API_URL=http://169.58.40.160/api `
  --dart-define=PP_ALLOW_INSECURE_HTTP=true
