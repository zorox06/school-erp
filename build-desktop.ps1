param(
    [switch]$Release,
    [switch]$Debug,
    [switch]$AppBundle,
    [ValidateSet('android-arm64', 'android-arm', 'android-x64')]
    [string]$TargetPlatform = 'android-arm64'
)
$ErrorActionPreference = 'Stop'
if ($Debug -and ($Release -or $AppBundle)) {
    throw 'Use -Debug for development or -Release/-AppBundle for distribution.'
}
if ($AppBundle -and $PSBoundParameters.ContainsKey('TargetPlatform')) {
    throw 'An app bundle includes all supported Android architectures. Use -TargetPlatform for an APK.'
}
Push-Location $PSScriptRoot
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
    flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
    if ($AppBundle) {
        flutter build appbundle --release --dart-define-from-file=config/supabase.local.json
        if ($LASTEXITCODE -ne 0) { throw 'Android App Bundle build failed.' }
        $artifact = 'build/app/outputs/bundle/release/app-release.aab'
        $filename = 'Schoolday.aab'
    } else {
        $mode = if ($Release) { 'release' } elseif ($Debug) { 'debug' } else { 'profile' }
        flutter build apk "--$mode" --split-per-abi "--target-platform=$TargetPlatform" --android-project-arg=force-version-code-ignoring-abi=true --dart-define-from-file=config/supabase.local.json
        if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
        $abi = @{
            'android-arm64' = 'arm64-v8a'
            'android-arm' = 'armeabi-v7a'
            'android-x64' = 'x86_64'
        }[$TargetPlatform]
        $artifact = "build/app/outputs/flutter-apk/app-$abi-$mode.apk"
        $filename = if ($Release) { 'Schoolday.apk' } else { "Schoolday-$mode.apk" }
    }
    $taskDesktopPath = [Environment]::GetFolderPath('Desktop')
    $destination = Join-Path $taskDesktopPath $filename
    Copy-Item -LiteralPath $artifact -Destination $destination -Force
    $sizeMB = (Get-Item -LiteralPath $destination).Length / 1000000
    Write-Host ('{0} ({1:N1} MB)' -f $destination, $sizeMB)
} finally { Pop-Location }
