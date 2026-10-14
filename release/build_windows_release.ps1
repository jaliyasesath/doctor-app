param(
  [Parameter(Mandatory=$true)][string]$ApiUrl,
  [string]$ProjectRoot = '',
  [string]$IsccPath = '',
  [switch]$AllowInsecureHttpForTesting,
  [switch]$SkipTests,
  [switch]$AllowAnalyzerWarnings
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $ProjectRoot) { $ProjectRoot = Join-Path $PSScriptRoot '..' }
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$uri = $null
if (-not [Uri]::TryCreate($ApiUrl, [UriKind]::Absolute, [ref]$uri) -or
    ($uri.Scheme -ne 'https' -and
      -not ($AllowInsecureHttpForTesting -and $uri.Scheme -eq 'http')) -or -not $uri.Host -or $uri.UserInfo -or
    $uri.Query -or $uri.Fragment) {
  throw 'Provide an HTTPS API URL, or HTTP with -AllowInsecureHttpForTesting. No credentials/query/fragment.'
}
$ApiUrl = $ApiUrl.TrimEnd('/')
$insecureFlag = if ($AllowInsecureHttpForTesting) { 'true' } else { 'false' }
$buildChannel = if ($AllowInsecureHttpForTesting) { 'UAT' } else { 'Production' }
$artifactSuffix = if ($AllowInsecureHttpForTesting) { '_UAT' } else { '' }
if ($AllowInsecureHttpForTesting) {
  Write-Warning 'UAT installer: HTTP traffic is unencrypted. Use test data only.'
}
if (-not (Test-Path (Join-Path $ProjectRoot 'windows/CMakeLists.txt'))) {
  throw 'Run this against your complete Flutter project with existing Windows sources.'
}
$pubspec = Get-Content (Join-Path $ProjectRoot 'pubspec.yaml') -Raw
$match = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$')
if (-not $match.Success) { throw 'Expected pubspec version: major.minor.patch+build.' }
$version = $match.Groups[1].Value
$buildNumber = $match.Groups[2].Value
$cmake = Get-Content (Join-Path $ProjectRoot 'windows/CMakeLists.txt') -Raw
$binary = [regex]::Match($cmake, 'set\(BINARY_NAME\s+"([A-Za-z0-9_-]+)"\)')
if (-not $binary.Success) { throw 'Cannot resolve the existing Windows BINARY_NAME.' }
$exeName = $binary.Groups[1].Value + '.exe'
Get-Command flutter -ErrorAction Stop | Out-Null

function Invoke-Flutter([string[]]$Arguments) {
  & flutter @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Flutter failed: $($Arguments[0]) ($LASTEXITCODE)" }
}

Push-Location $ProjectRoot
try {
  Invoke-Flutter -Arguments @('pub','get')
  if ($AllowInsecureHttpForTesting -or $AllowAnalyzerWarnings) {
  Invoke-Flutter -Arguments @(
    'analyze', '--no-fatal-infos', '--no-fatal-warnings'
  )
} else {
  Invoke-Flutter -Arguments @('analyze')
}
  if (-not $SkipTests) {
    # Client session tests use MockClient; this origin only satisfies URL
    # validation. It does not contact the hosted API or change app builds.
    Invoke-Flutter -Arguments @('test',
      '--dart-define=PP_CLIENT_API_URL=https://pp-client.test')
  }
  # Override UAT defaults explicitly without changing mobile configuration.
  Invoke-Flutter -Arguments @('build','windows','--release',
    "--dart-define=PP_CLOUD_API_URL=$ApiUrl",
    "--dart-define=PP_ALLOW_INSECURE_HTTP=$insecureFlag")
  $release = Join-Path $ProjectRoot 'build/windows/x64/runner/Release'
  if (-not (Test-Path (Join-Path $release $exeName))) {
    throw 'Expected x64 release executable missing. Check your Flutter target architecture/build output.'
  }
  if (-not (Test-Path (Join-Path $release 'flutter_windows.dll')) -or
      -not (Test-Path (Join-Path $release 'data/flutter_assets'))) {
    throw 'Incomplete release bundle: runtime DLL or Flutter assets missing.'
  }
  if (-not $IsccPath) {
    $candidates = @(
      (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6/ISCC.exe'),
      (Join-Path $env:LOCALAPPDATA 'Programs/Inno Setup 6/ISCC.exe')
    )
    foreach ($candidate in $candidates) {
      if (Test-Path $candidate) { $IsccPath = $candidate; break }
    }
  }
  if (-not $IsccPath -or -not (Test-Path $IsccPath)) {
    throw "Release bundle built at $release. Install Inno Setup 6 or specify -IsccPath to create installer."
  }
  $output = Join-Path $ProjectRoot "dist/windows/$buildChannel"
  New-Item -ItemType Directory -Force $output | Out-Null
  $installerScript = Join-Path $PSScriptRoot 'pp_app_setup.iss'
  & $IsccPath "/DAppVersion=$version" "/DBuildNumber=$buildNumber" "/DAppExe=$exeName" "/DReleaseDir=$release" "/DInstallerOutput=$output" "/DArtifactSuffix=$artifactSuffix" $installerScript
  if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
  $installer = Join-Path $output "PP_App_Setup_${version}_${buildNumber}${artifactSuffix}.exe"
  if (-not (Test-Path $installer)) { throw 'Installer output missing.' }
  $hash = (Get-FileHash $installer -Algorithm SHA256).Hash
  "$hash  $(Split-Path $installer -Leaf)" | Set-Content "$installer.sha256" -Encoding ASCII
  [ordered]@{
    channel=$buildChannel; insecureHttpAllowed=[bool]$AllowInsecureHttpForTesting;
    name='PP App'; version=$version; build=$buildNumber;
    apiUrl=$ApiUrl; architecture='x64'; builtAtUtc=[DateTime]::UtcNow.ToString('o');
    installerSha256=$hash; testsSkipped=[bool]$SkipTests; analyzerWarningsAllowed=[bool]$AllowAnalyzerWarnings;
    flutterVersion=((& flutter --version) -join "`n")
  } | ConvertTo-Json | Set-Content (Join-Path $output 'release_build_info.json') -Encoding UTF8
  Write-Host "Installer prepared: $installer"
  Write-Host 'Unsigned build. Complete regression/security checks and signing before public release.'
} finally { Pop-Location }
