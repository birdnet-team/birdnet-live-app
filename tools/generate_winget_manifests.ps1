# =============================================================================
# tools/generate_winget_manifests.ps1
#
# Generates Winget manifest files for a published BirdNET Live release by
# downloading the installer and computing its SHA256 hash.
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$PackageIdentifier,

    [Parameter(Mandatory = $true)]
    [string]$PackageVersion,

    [Parameter(Mandatory = $true)]
    [string]$InstallerUrl,

    [string]$Publisher = 'BirdNET',
    [string]$PackageName = 'BirdNET Live',
    [string]$Moniker = 'birdnet-live',
    [string]$License = 'MIT',
    [string]$ShortDescription = 'Real-time bird species identification using on-device BirdNET+ inference.',
    [string]$PublisherUrl = 'https://github.com/birdnet-team',
    [string]$PackageUrl = 'https://github.com/birdnet-team/birdnet-live-app',
    [string]$PublisherSupportUrl = 'https://github.com/birdnet-team/birdnet-live-app/issues',
    [string]$ReleaseNotesUrl,
    [string]$OutputRoot = 'release/winget'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ReleaseNotesUrl)) {
    $ReleaseNotesUrl = $PackageUrl + '/releases/tag/v' + $PackageVersion
}

$segments = $PackageIdentifier.Split('.')
if ($segments.Length -lt 2) {
    throw 'PackageIdentifier must be a dot-separated identifier, for example: BirdNET-Team.BirdNETLive'
}

$manifestsRoot = Join-Path $OutputRoot 'manifests'
$firstChar = $segments[0].Substring(0, 1).ToLowerInvariant()
$packagePath = Join-Path $manifestsRoot $firstChar
foreach ($segment in $segments) {
    $packagePath = Join-Path $packagePath $segment
}

$versionDir = Join-Path $packagePath $PackageVersion
New-Item -ItemType Directory -Path $versionDir -Force | Out-Null

$tempInstaller = Join-Path ([System.IO.Path]::GetTempPath()) ("winget_" + [Guid]::NewGuid().ToString('N') + '.exe')
$maxAttempts = 8
$delaySeconds = 15
$downloaded = $false

for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
  try {
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $tempInstaller
    $downloaded = $true
    break
  }
  catch {
    if ($attempt -eq $maxAttempts) {
      throw "Failed to download installer after $maxAttempts attempts: $InstallerUrl`n$($_.Exception.Message)"
    }
    Write-Host "Download attempt $attempt/$maxAttempts failed. Retrying in $delaySeconds seconds..."
    Start-Sleep -Seconds $delaySeconds
  }
}

if (-not $downloaded) {
  throw "Installer download did not succeed: $InstallerUrl"
}

$installerSha256 = (Get-FileHash -Path $tempInstaller -Algorithm SHA256).Hash.ToUpperInvariant()
Remove-Item -Path $tempInstaller -Force

$versionManifestPath = Join-Path $versionDir "$PackageIdentifier.yaml"
$installerManifestPath = Join-Path $versionDir "$PackageIdentifier.installer.yaml"
$defaultLocaleManifestPath = Join-Path $versionDir "$PackageIdentifier.locale.en-US.yaml"

$versionManifest = @"
PackageIdentifier: $PackageIdentifier
PackageVersion: $PackageVersion
DefaultLocale: en-US
ManifestType: version
ManifestVersion: 1.10.0
"@

$installerManifest = @"
PackageIdentifier: $PackageIdentifier
PackageVersion: $PackageVersion
InstallerType: inno
Scope: user
InstallModes:
  - interactive
  - silent
  - silentWithProgress
InstallerSwitches:
  Silent: /VERYSILENT /NORESTART
  SilentWithProgress: /SILENT /NORESTART
UpgradeBehavior: install
Installers:
  - Architecture: x64
    InstallerUrl: $InstallerUrl
    InstallerSha256: $installerSha256
ManifestType: installer
ManifestVersion: 1.10.0
"@

$defaultLocaleManifest = @"
PackageIdentifier: $PackageIdentifier
PackageVersion: $PackageVersion
PackageLocale: en-US
Publisher: $Publisher
PublisherUrl: $PublisherUrl
PublisherSupportUrl: $PublisherSupportUrl
PackageName: $PackageName
PackageUrl: $PackageUrl
License: $License
ShortDescription: $ShortDescription
Moniker: $Moniker
ReleaseNotesUrl: $ReleaseNotesUrl
ManifestType: defaultLocale
ManifestVersion: 1.10.0
"@

Set-Content -Path $versionManifestPath -Value $versionManifest -Encoding utf8
Set-Content -Path $installerManifestPath -Value $installerManifest -Encoding utf8
Set-Content -Path $defaultLocaleManifestPath -Value $defaultLocaleManifest -Encoding utf8

Write-Host "Winget manifests written to: $versionDir"
Write-Host "Installer SHA256: $installerSha256"
