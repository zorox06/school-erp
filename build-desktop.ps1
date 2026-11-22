param([switch]$Release)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    $mode = if ($Release) { "release" } else { "debug" }
    flutter build apk "--$mode" --dart-define-from-file=config/supabase.local.json
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    $taskDesktopPath = [Environment]::GetFolderPath('Desktop')
    Copy-Item -LiteralPath "build/app/outputs/flutter-apk/app-$mode.apk" -Destination (Join-Path $taskDesktopPath 'Schoolday.apk') -Force
    Write-Host 'Schoolday.apk has been copied to your desktop.'
} finally { Pop-Location }
