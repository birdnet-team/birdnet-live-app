# =============================================================================
# dev/build_inno_installer.ps1
#
# Builds a Windows release folder and packages it as an Inno Setup installer.
# Intended for local test builds and CI usage where the installer may be signed
# later as a separate artifact.
# =============================================================================

param(
    [switch]$SkipFlutterBuild,
    [string]$Configuration = 'Release'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$match = Select-String -Path 'pubspec.yaml' -Pattern '^version:\s*(.+)$'
if (-not $match) { throw 'Could not parse version from pubspec.yaml' }
$appVersion = $match.Matches[0].Groups[1].Value.Trim().Split('+')[0]

$releaseDir = Join-Path $repoRoot "build/windows/x64/runner/$Configuration"
$installerScript = Join-Path $repoRoot 'windows/installer/birdnet_live.iss'
$outputDir = Join-Path $repoRoot 'build/windows/x64/runner'
$staleFlutterAssetDir = Join-Path $repoRoot 'build/flutter_assets'
$isccCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
)

$isccCommand = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
if ($isccCommand) {
    $isccCandidates = @($isccCommand.Source) + $isccCandidates
}

$isccPath = $isccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $isccPath) {
    throw 'Inno Setup 6 is not installed. Install it with `winget install JRSoftware.InnoSetup` or from https://jrsoftware.org/isinfo.php.'
}

if (-not $SkipFlutterBuild) {
    if (Test-Path $staleFlutterAssetDir) {
        # Flutter can fail on Windows if a previous asset bundle left files in place.
        Remove-Item $staleFlutterAssetDir -Recurse -Force
    }

    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed (exit $LASTEXITCODE)" }
}

if (-not (Test-Path $releaseDir)) {
    throw "Windows release folder not found: $releaseDir"
}

$installerPath = Join-Path $outputDir "BirdNET_Live_v${appVersion}_windows_x64_setup.exe"
if (Test-Path $installerPath) {
    Remove-Item $installerPath -Force
}

& $isccPath "/DMyAppVersion=$appVersion" "/DMySourceDir=$releaseDir" "/DMyOutputDir=$outputDir" $installerScript
if ($LASTEXITCODE -ne 0) { throw "ISCC failed (exit $LASTEXITCODE)" }

Write-Host "Installer written to: $installerPath"
