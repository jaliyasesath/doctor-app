param(
  [string]$ProjectRoot = (Join-Path $PSScriptRoot '..'),
  [string]$IconPath = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$runner = Join-Path $ProjectRoot 'windows/runner'
$mainPath = Join-Path $runner 'main.cpp'
$resourcePath = Join-Path $runner 'Runner.rc'
$main = Get-Content $mainPath -Raw
$resource = Get-Content $resourcePath -Raw
$titlePattern = '(window\.Create\(L")([^"]+)(")'
if ([regex]::Matches($main, $titlePattern).Count -ne 1) {
  throw 'Expected one native window.Create title; inspect main.cpp manually. Nothing changed.'
}
$newMain = [regex]::Replace($main, $titlePattern, '${1}PP App${3}')
$newResource = $resource
foreach ($field in @('FileDescription','ProductName')) {
  $pattern = '(VALUE\s+"' + $field + '"\s*,\s*")[^"]*(")'
  if ([regex]::Matches($resource, $pattern).Count -ne 1) {
    throw "Expected one $field resource entry. Nothing changed."
  }
  $newResource = [regex]::Replace($newResource, $pattern, '${1}PP App\0${2}')
}
if ($IconPath) {
  $IconPath = (Resolve-Path $IconPath).Path
  $bytes = [IO.File]::ReadAllBytes($IconPath)
  if ($bytes.Length -lt 6 -or $bytes[0] -ne 0 -or $bytes[1] -ne 0 -or
      $bytes[2] -ne 1 -or $bytes[3] -ne 0) {
    throw 'Provide a valid Windows ICO file, not a renamed PNG/JPEG.'
  }
  if (-not (Test-Path (Join-Path $runner 'resources/app_icon.ico'))) {
    throw 'Existing native app_icon.ico missing; inspect your runner resource path.'
  }
}
# Preserve original build identity, executable name and storage paths.
$backup = Join-Path $ProjectRoot ('release-backups/branding-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Force $backup | Out-Null
Copy-Item $mainPath $backup
Copy-Item $resourcePath $backup
$encoding = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($mainPath, $newMain, $encoding)
[IO.File]::WriteAllText($resourcePath, $newResource, $encoding)
if ($IconPath) {
  $target = Join-Path $runner 'resources/app_icon.ico'
  Copy-Item $target (Join-Path $backup 'app_icon.ico')
  Copy-Item $IconPath $target -Force
} else {
  Write-Warning 'Existing native icon retained. Provide -IconPath with your approved PP App ICO before release.'
}
Write-Host "Windows display name prepared. Original native files backed up in $backup"
