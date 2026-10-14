param(
  [Parameter(Mandatory=$true)][string]$ApiUrl,
  [Parameter(Mandatory=$true)][string]$GoogleWebClientId,
  [ValidateSet('run','apk','appbundle')][string]$Action = 'run',
  [switch]$LocalHttp
)
$ErrorActionPreference = 'Stop'
$endpoint = [uri]$ApiUrl
if (-not $endpoint.IsAbsoluteUri -or $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment) {
  throw 'Supply an API origin without credentials, query or fragment.'
}
if ($endpoint.AbsolutePath.TrimEnd('/').EndsWith('/api')) { throw 'Supply the API origin without the final /api.' }
if (-not $GoogleWebClientId.EndsWith('.apps.googleusercontent.com')) { throw 'Supply the real Google Web Client ID.' }
if ($endpoint.Scheme -ne 'https') {
  if (-not ($LocalHttp -and $Action -eq 'run' -and $endpoint.Scheme -eq 'http' -and $endpoint.Host -in @('10.0.2.2','localhost','127.0.0.1'))) {
    throw 'Release builds require HTTPS. Local HTTP is allowed only for debug emulator testing.'
  }
}
$clientArgs = @('--flavor','client','-t','lib/main_client.dart',
  "--dart-define=PP_CLIENT_API_URL=$($ApiUrl.TrimEnd('/'))",
  "--dart-define=PP_CLIENT_GOOGLE_WEB_ID=$GoogleWebClientId")
if ($LocalHttp) { $clientArgs += '--dart-define=PP_CLIENT_LOCAL_HTTP=true' }
if ($Action -eq 'run') { & flutter run --debug @clientArgs }
else { & flutter build $Action --release @clientArgs }
if ($LASTEXITCODE -ne 0) { throw 'PP Client build/run failed.' }
