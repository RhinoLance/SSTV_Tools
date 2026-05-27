function Get-WindowTitle {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory, Position = 0)]
		[string]$WindowName,

		[Parameter()]
		[string[]]$Exclude = @(),

		[Parameter()]
		[switch]$GetParent
	)

	Begin {
		Initialize-Win32NativeTypes
	}

	Process {
		
		$hwnd = Get-WindowHandleByName -WindowName $WindowName -Exclude $Exclude

		if ($hwnd -eq [IntPtr]::Zero) {
			throw "Window with name '$WindowName' not found."
		}

		$targetHwnd = [IntPtr]::Zero
		
		if ( $GetParent.IsPresent ) {
			$targetHwnd = [SSTVToolsWin32]::GetParent($hwnd)
			if ( $targetHwnd -eq [IntPtr]::Zero) {
				$targetHwnd = [SSTVToolsWin32]::GetAncestor($hwnd, 2) # Get root ancestor
			}
			if ( $targetHwnd -eq [IntPtr]::Zero) {
				throw "Failed to get parent window handle for child window $hwnd."
			}
		}
		else {
			$targetHwnd = $hwnd
		}

		# Get and display window name
		$len = [SSTVToolsWin32]::GetWindowTextLength($targetHwnd)
		if ($len -gt 0) {
			$sb = New-Object System.Text.StringBuilder ($len + 1)
			[SSTVToolsWin32]::GetWindowText($targetHwnd, $sb, $sb.Capacity) | Out-Null
			$windowTitle = $sb.ToString()
			
			return $windowTitle
		}

		Write-Warning "Window found but has no title."

		return -1
	}
}

Export-ModuleMember -Function Get-WindowTitle

