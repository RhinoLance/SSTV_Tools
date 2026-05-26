param(
    [switch]$Prerelease,
    [string]$ApiKeyEnvVar = "PSGALLERY_API_KEY"
)

# Ensure PowerShellGet is available
try {
    Import-Module PowerShellGet -ErrorAction Stop
} catch {
    Write-Warning "PowerShellGet not available. Install it with: Install-Module PowerShellGet -Scope CurrentUser -Force"
}

function Run {
    param([string]$Cmd)
    Write-Host "`n▶ $Cmd" -ForegroundColor Cyan
    try {
        Invoke-Expression -Command $Cmd -ErrorAction Stop
    } catch {
        Write-Error "Command failed: $Cmd`n$($_.Exception.Message)"
        exit 1
    }
}

# 1. Ensure module manifest exists
$manifest = Get-ChildItem -Filter *.psd1 | Select-Object -First 1
if (-not $manifest) {
    Write-Error "No module manifest (*.psd1) found."
    exit 1
}

Write-Host "Using manifest: $($manifest.Name)"

# 2. Load manifest
# Validate and read manifest
$moduleInfo = Test-ModuleManifest -Path $manifest.FullName
$version    = $moduleInfo.Version.ToString()

Write-Host "Current version: $version"

# 3. Bump version automatically
if ($Prerelease) {
    Write-Warning "Prerelease publishing: module manifests use strict version formats.\nIf you need a prerelease package, update the PSD1 Version manually to a prerelease-capable package or handle packaging separately. Proceeding to publish current manifest version ($version)."
    $newVersion = $version
} else {
    $parts = $version.Split('.')
    while ($parts.Count -lt 3) { $parts += '0' }
    $parts[2] = ([int]$parts[2] + 1).ToString()
    $newVersion = "$($parts[0]).$($parts[1]).$($parts[2])"
    Run "Update-ModuleManifest -Path '$($manifest.FullName)' -Version '$newVersion'"
    Write-Host "Bumped version to $newVersion"
}

# 4. Validate manifest again
Run "Test-ModuleManifest -Path '$($manifest.FullName)'"

# 5. Load API key
$apiKey = [Environment]::GetEnvironmentVariable($ApiKeyEnvVar)
if (-not $apiKey) {
    Write-Error "Environment variable '$ApiKeyEnvVar' not set."
    exit 1
}

# 6. Publish
# Publish using the module folder that contains the manifest
# Determine publish method: prefer PSResource (PSGallery v3+/PSResource) on PS7
$modulePath = $manifest.DirectoryName
$usePSResource = $false
if (Get-Command -Name Publish-PSResource -ErrorAction SilentlyContinue) {
    $usePSResource = $true
    if (Get-Command -Name Get-PSResourceRepository -ErrorAction SilentlyContinue) {
        try {
            Get-PSResourceRepository -Name PSGallery -ErrorAction Stop | Out-Null
        } catch {
            $usePSResource = $false
        }
    }
}

if ($usePSResource) {
    Write-Host "Using Publish-PSResource (PSResource/PowerShellGet v3+) to publish." -ForegroundColor Cyan
    try {
        if ($apiKey) {
            Publish-PSResource -Path $modulePath -Repository PSGallery -ApiKey $apiKey -Verbose -ErrorAction Stop
        } else {
            Publish-PSResource -Path $modulePath -Repository PSGallery -Verbose -ErrorAction Stop
        }
    } catch {
        Write-Warning "Publish-PSResource failed: $($_.Exception.Message)"
        Write-Host "Falling back to Publish-Module." -ForegroundColor Yellow
        $usePSResource = $false
    }
}

Write-Host "`n🎉 Module published successfully!" -ForegroundColor Green
