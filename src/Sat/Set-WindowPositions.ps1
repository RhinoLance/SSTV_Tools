param(
	[string]$ConfigPath = ".\config.json",
	[switch]$Debug
)

if( $debug ) {
	Write-Host "Debug mode enabled"
	Import-Module ..\PowerShell\Modules\SSTV-Tools
}
else{
	Import-Module SSTV-Tools
}

function Set-ConfiguredWindowPosition {
	param(
		$Window,
		$Exclude = @()
	)

	if( $null -eq $Window -or $null -eq $Window.position ) {
		return
	}

	$position = $Window.position
	Write-Host "Setting $($Window.name) window position to: $($position | ConvertTo-Json -Compress)"
	$null = Set-WindowPos -WindowName $Window.name -Exclude $Exclude -X $position.left -Y $position.top -Width $position.width -Height $position.height
}

$config = @{}
if( (Test-Path $ConfigPath)) {
	Write-Host "Config loaded from $ConfigPath"
	$config = Get-Content -Path $ConfigPath | ConvertFrom-Json
}
else {
	$config.tempWorkingDir = [System.IO.Path]::GetTempPath() + "/SSTVPrep"
}

if( $null -ne $config.windows ) {
	$windows = @($config.windows.PSObject.Properties.Value)

	Write-Host "Setting window positions for $($windows.Count) windows"

	foreach( $window in $windows ) {
		if( $null -eq $window ) {
			continue
		}

		$exclude = @()
		if( $null -ne $window.exclude ) {
			$exclude = @($window.exclude)
		}

		Set-ConfiguredWindowPosition -Window $window -Exclude $exclude
	}
}

