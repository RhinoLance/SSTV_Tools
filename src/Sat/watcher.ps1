param(
	[string]$ConfigPath = ".\config.json"
)

Import-Module SSTV-Tools

& ./Set-WindowPositions.ps1 -ConfigPath $ConfigPath

$config = @{}
if( (Test-Path $configPath)) {
	Write-Host "Watcher config loaded from $ConfigPath"
	$config = Get-Content -Path $configPath | ConvertFrom-Json
}
else {
	$config.tempWorkingDir = [System.IO.Path]::GetTempPath() + "/SSTVPrep"
}

$action = { 
	param($event)
	try{
		Write-Host "File updated: $($event.EventType) File: $($event.FullPath)"

		$runnerProps = @{
			ImagePath = "$($config.tempWorkingDir)\latest.bmp"
			TempWorkingDir = "$($config.tempWorkingDir)"
		}

		Copy-Item -Path $event.FullPath -Destination $($runnerProps.ImagePath) -Force
		
		& "./runner.ps1" @runnerProps
		
	}
	catch {
		Write-Host "Error in event handler: $_"
	}
	
}
$params = @{
	Folder = $config.watchFolder ?? "C:\Ham\MMSSTV\History"
	Filter = $config.watchFilter ?? "*.bmp"
	Action = $action
	Events = @("Changed")
	DebounceSeconds = 5
}
$wh = Start-WatchFile @params

Write-Host "Press Enter or Ctrl-C to quit"
Write-Host

# Register an engine exit handler so Stop-WatchFile runs if PowerShell exits
$reg = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
	try {
		Stop-WatchFile -Handle $using:wh
	} catch {}
}

$canUseConsole = $false
try { $null = [Console]::KeyAvailable; $canUseConsole = $true } catch {}

try {
	if ($canUseConsole -and $Host.Name -ne 'Windows PowerShell ISE Host') {
		while (-not ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Enter')) {
			Start-Sleep -Milliseconds 200
		}
	}
	else {
		# Fallback for hosts without Console support
		Read-Host
	}
}
finally {
	try { Stop-WatchFile -Handle $wh } catch {}
	try { Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue } catch {}
	Write-Host
	Write-Host "Stopped."
}