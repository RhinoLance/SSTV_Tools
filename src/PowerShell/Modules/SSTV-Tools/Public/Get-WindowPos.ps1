function Get-WindowPos {
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

		$rect = New-Object SSTVToolsWin32+RECT
		[SSTVToolsWin32]::GetWindowRect($targetHwnd, [ref]$rect)

		$output = New-Object PSObject -Property @{
			Left   = $rect.Left
			Top    = $rect.Top
			Right  = $rect.Right
			Bottom = $rect.Bottom
			Width  = $rect.Right - $rect.Left
			Height = $rect.Bottom - $rect.Top
		}

		return $output
	}
}

Export-ModuleMember -Function Get-WindowPos

