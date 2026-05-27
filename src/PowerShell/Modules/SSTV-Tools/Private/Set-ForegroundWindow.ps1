function Set-ForegroundWindow {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory, ParameterSetName='ByName')]
		[string]$WindowName,

		[Parameter(ParameterSetName='ByName')]
		[string[]]$Exclude = @(),

		[Parameter(Mandatory, ParameterSetName='ByHandle')]
		[System.IntPtr]$hWnd,

		[Parameter()]
		[switch]$PassThru
	)

	Initialize-Win32NativeTypes

	if ($PSCmdlet.ParameterSetName -eq 'ByName') {
		$hWnd = Get-WindowHandleByName -WindowName $WindowName -Exclude $Exclude
	}

	if ($hwnd -eq [System.IntPtr]::Zero) {
		if ($PSCmdlet.ParameterSetName -eq 'ByHandle') {
			throw "Window handle cannot be IntPtr.Zero."
		}

		throw "Window with name '$WindowName' not found."
	}

	$GA_ROOT = 2
	$SW_RESTORE = 9

	$target = [SSTVToolsWin32]::GetAncestor($hwnd, $GA_ROOT)
	if ($target -eq [System.IntPtr]::Zero) {
		$target = $hwnd
	}

	if ([SSTVToolsWin32]::IsIconic($target)) {
		[SSTVToolsWin32]::ShowWindow($target, $SW_RESTORE) | Out-Null
	}

	$focused = [SSTVToolsWin32]::SetForegroundWindow($target)
	if (-not $focused) {
		if ($PSCmdlet.ParameterSetName -eq 'ByHandle') {
			throw ("Failed to set foreground window for handle 0x{0:X}." -f $hWnd.ToInt64())
		}

		throw "Failed to set foreground window for '$WindowName'."
	}

	if ($PassThru) {
		return $target
	}

	return $true
}
