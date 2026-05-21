$lastTimeDict = @{}

function Start-WatchFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] [string] $Folder,
		[Parameter(Mandatory=$false)] [string] $Filter = '*.*',
		[Parameter(Mandatory=$false)] [scriptblock] $Action,
		[Parameter(Mandatory=$false)] [string[]] $Events = @("Changed", "Created", "Deleted", "Renamed"),
		[Parameter(Mandatory=$false)] [int] $DebounceSeconds = 0
	)

	Write-Host "Starting to watch folder: $Folder with filter: $Filter"

	$watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $Folder
    $watcher.Filter = $Filter
    $watcher.IncludeSubdirectories = $true
    $watcher.EnableRaisingEvents = $true  

	$events = $Events | ForEach-Object { $_.Trim() } # Trim whitespace

	$subs = @()
	foreach ($name in $events) {
		$params = @{
			InputObject = $watcher 
			EventName = $name
			SourceIdentifier = [guid]::NewGuid().ToString()
			MessageData = @{ UserAction = $Action; LastTimeDict = $lastTimeDict; DebounceSeconds = $DebounceSeconds }
			Action = {
				$runtimeData = @{
					EventType 	= $Event.SourceEventArgs.ChangeType
					FullPath 	= $Event.SourceEventArgs.FullPath
					Name 		= $Event.SourceEventArgs.Name
					Time 		= $Event.TimeGenerated
					OriginalEvent = $Event.SourceIdentifier
					EventName 	= $Event.SourceIdentifier.Split('.')[1]
					Sender 	= $Event.Sender
				}
				$md = $runtimeData + $Event.MessageData
				New-Event -SourceIdentifier "UnifiedFsEvent" -MessageData $md
			}

		}
		$subs += Register-ObjectEvent @params
	}

	$engineSub = Register-EngineEvent -SourceIdentifier "UnifiedFsEvent" -Action {
		try{
			$lastTimeDict = $event.MessageData.LastTimeDict
			$debounce = $event.MessageData.DebounceSeconds
			$eventType = $event.MessageData.EventType

			$envtTime = [long]($event.MessageData.Time.Ticks / 10000 / 1000 * 1) # 1 second resolution

			if( !$lastTimeDict.ContainsKey($eventType) ) {
				$lastTimeDict[$eventType] = 0
			}

			if( $envtTime -gt ($lastTimeDict[$eventType] + $debounce) ) {

				$responseData = @{
					EventType 	= $event.MessageData.EventType
					FullPath 	= $event.MessageData.FullPath
					Name 		= $event.MessageData.Name
					Time 		= $event.MessageData.Time
					EventName 	= $event.MessageData.EventName
				}

				& $event.MessageData.UserAction $responseData

				$lastTimeDict[$eventType] = $envtTime
			}
		}
		catch {
			Write-Host "Error in unified Watch-Fileevent handler: $_"
		}
	}

	$stop = {
		foreach ($s in $subs) {
			
			if (-not $s) { continue }

			if ($s.PSObject.Properties['Id'] -and $s.Id) {
				Unregister-Event -SubscriptionId $s.Id -ErrorAction SilentlyContinue
			}
			elseif ($s.PSObject.Properties['SubscriptionId'] -and $s.SubscriptionId) {
				Unregister-Event -SubscriptionId $s.SubscriptionId -ErrorAction SilentlyContinue
			}
			elseif ($s.PSObject.Properties['SourceIdentifier'] -and $s.SourceIdentifier) {
				Unregister-Event -SourceIdentifier $s.SourceIdentifier -ErrorAction SilentlyContinue
			}
			else {
				Write-Warning "Unable to unregister event subscription: $s"
			}
		}

		if ($engineSub) {
			if ($engineSub.PSObject.Properties['Id'] -and $engineSub.Id) { Unregister-Event -SubscriptionId $engineSub.Id -ErrorAction SilentlyContinue }
			elseif ($engineSub.PSObject.Properties['SubscriptionId'] -and $engineSub.SubscriptionId) { Unregister-Event -SubscriptionId $engineSub.SubscriptionId -ErrorAction SilentlyContinue }
			elseif ($engineSub.PSObject.Properties['SourceIdentifier'] -and $engineSub.SourceIdentifier) { Unregister-Event -SourceIdentifier $engineSub.SourceIdentifier -ErrorAction SilentlyContinue }
		}

		if ($watcher) { $watcher.Dispose() }
	}

	return [pscustomobject]@{
		Watcher = $watcher
		Subscriptions = $subs
		EngineSubscription = $engineSub
		Stop = $stop
	}

}

function Stop-WatchFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)] $Handle
	)

	process {
		if ($null -eq $Handle) { return }
		try {
			if ($Handle.PSObject.Properties['Stop']) {
				& $Handle.Stop | Out-Host
			}
			else {
				Write-Warning "Provided handle does not have a Stop method. Ensure you are passing the object returned by Start-WatchFile."
			}
		}
		catch {
			Write-Error "Failed to stop watcher: $_"
		}
	}
}

Export-ModuleMember -Function Start-WatchFile, Stop-WatchFile