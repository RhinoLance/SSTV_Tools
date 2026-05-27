function Get-WindowHandleByName {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$WindowName,

		[Parameter()]
		[string[]]$Exclude = @()
	)

	Initialize-Win32NativeTypes

	$hwnd = [IntPtr]::Zero

	# Try exact match first.
	try {
		$hwnd = [SSTVToolsWin32]::FindWindow($null, $WindowName)
	}
	catch {
		$hwnd = [IntPtr]::Zero
	}

	# Fallback: partial, case-insensitive title match.
	if ($hwnd -eq [IntPtr]::Zero) {
		$script:found = [IntPtr]::Zero
		$callback = [SSTVToolsWin32+EnumWindowsProc]{
			param([IntPtr]$hWnd, [IntPtr]$lParam)
			if (-not [SSTVToolsWin32]::IsWindowVisible($hWnd)) { return $true }
			$len = [SSTVToolsWin32]::GetWindowTextLength($hWnd)
			if ($len -le 0) { return $true }
			$sb = New-Object System.Text.StringBuilder ($len + 1)
			[SSTVToolsWin32]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
			$title = $sb.ToString()
			if ($title -and $title.IndexOf($WindowName, [System.StringComparison]::CurrentCultureIgnoreCase) -ge 0) {
				foreach ($exclude in $Exclude) {
					if ([string]::IsNullOrWhiteSpace($exclude)) { continue }
					if ($title.IndexOf($exclude, [System.StringComparison]::CurrentCultureIgnoreCase) -ge 0) {
						return $true
					}
				}

				$script:found = $hWnd
				return $false
			}
			return $true
		}

		[SSTVToolsWin32]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
		if ($script:found -ne [IntPtr]::Zero) { $hwnd = $script:found }
	}

	return $hwnd
}
