function Get-WindowTitle {
	[CmdletBinding()]
	param(
		[Parameter(Position=0)]
		[string]$WindowName,

		[Parameter(Position=1)]
		[string]$Ignore = $null,

		[Parameter()]
		[switch]$GetParent
	)

	Begin {
		$win32 = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class Win32 {
	public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
	[DllImport("user32.dll")]
	public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern int GetWindowTextLength(IntPtr hWnd);
	[DllImport("user32.dll")]
	[return: MarshalAs(UnmanagedType.Bool)]
	public static extern bool IsWindowVisible(IntPtr hWnd);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
	[DllImport("user32.dll")]
	public static extern IntPtr GetParent(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
}
"@

		# Only add the Win32 type if it hasn't already been defined in this session
		if (-not ([AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('Win32') } | Where-Object { $_ })) {
			Add-Type -TypeDefinition $win32 -ErrorAction Stop | Out-Null
		}
	}

	Process {
		
		$hwnd = [IntPtr]::Zero

		# Try exact match using FindWindow first
		try {
			$hwnd = [Win32]::FindWindow($null, $WindowName)
		}
		catch {
			$hwnd = [IntPtr]::Zero
		}

		# If exact match failed, enumerate windows and look for a partial (case-insensitive) title match
		if ($hwnd -eq [IntPtr]::Zero) {
			$script:found = [IntPtr]::Zero
			$callback = [Win32+EnumWindowsProc]{
				param([IntPtr]$hWnd, [IntPtr]$lParam)
				if (-not [Win32]::IsWindowVisible($hWnd)) { return $true }
				$len = [Win32]::GetWindowTextLength($hWnd)
				if ($len -le 0) { return $true }
				$sb = New-Object System.Text.StringBuilder ($len + 1)
				[Win32]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
				$title = $sb.ToString()
				if ($title -and $title.IndexOf($WindowName, [System.StringComparison]::CurrentCultureIgnoreCase) -ge 0) {
					
					if( $Ignore -and $title.IndexOf($Ignore, [System.StringComparison]::CurrentCultureIgnoreCase) -ge 0) {
						return $true
					}

					$script:found = $hWnd
					return $false
				}
				return $true
			}

			[Win32]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
			if ($script:found -ne [IntPtr]::Zero) { $hwnd = $script:found }
		}

		if ($hwnd -eq [IntPtr]::Zero) {
			throw "Window with name '$WindowName' not found."
		}

		$targetHwnd = [IntPtr]::Zero
		
		if( $GetParent.IsPresent ) {
			$targetHwnd = [Win32]::GetParent($hwnd)
			if( $targetHwnd -eq [IntPtr]::Zero) {
				$targetHwnd = [Win32]::GetAncestor($hwnd, 2) # Get root ancestor
			}
			if( $targetHwnd -eq [IntPtr]::Zero) {
				throw "Failed to get parent window handle for child window $hwnd."
			}
		} else {
			$targetHwnd = $hwnd
		}

		# Get and display window name
		$len = [Win32]::GetWindowTextLength($targetHwnd)
		if ($len -gt 0) {
			$sb = New-Object System.Text.StringBuilder ($len + 1)
			[Win32]::GetWindowText($targetHwnd, $sb, $sb.Capacity) | Out-Null
			$windowTitle = $sb.ToString()
			
            return $windowTitle
		}

		Write-Warning "Window found but has no title."

		return -1
	}
}

Export-ModuleMember -Function Get-WindowTitle

