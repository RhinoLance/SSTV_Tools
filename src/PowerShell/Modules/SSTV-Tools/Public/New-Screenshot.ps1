function New-Screenshot {
	[CmdletBinding()]
	param(
		[Parameter(Position=0)]
		[string]$WindowName,

		[Parameter()]
		[switch]$GetParent,

		[Parameter(Position=1)]
		[string]$FilePath = ".\screenshot.png"
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
	[DllImport("user32.dll")]
	public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
	[DllImport("user32.dll", SetLastError=true)]
	public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
	public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
	[DllImport("user32.dll")]
    public static extern IntPtr GetParent(IntPtr hWnd);
	[DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);
	[DllImport("user32.dll")]
	public static extern bool IsIconic(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
	[DllImport("user32.dll")]
	public static extern bool SetForegroundWindow(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
	[DllImport("user32.dll")]
	public static extern IntPtr GetWindowDC(IntPtr hWnd);
	[DllImport("user32.dll")]
	public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);
	[DllImport("gdi32.dll")]
	public static extern IntPtr CreateCompatibleDC(IntPtr hdc);
	[DllImport("gdi32.dll")]
	public static extern IntPtr CreateCompatibleBitmap(IntPtr hdc, int nWidth, int nHeight);
	[DllImport("gdi32.dll")]
	public static extern IntPtr SelectObject(IntPtr hdc, IntPtr hgdiobj);
	[DllImport("gdi32.dll")]
	public static extern bool DeleteObject(IntPtr hObject);
	[DllImport("gdi32.dll")]
	public static extern bool DeleteDC(IntPtr hdc);
	[DllImport("gdi32.dll")]
	public static extern bool BitBlt(IntPtr hdcDest,int nXDest,int nYDest,int nWidth,int nHeight,IntPtr hdcSrc,int nXSrc,int nYSrc,int dwRop);
}
"@

		Add-Type -TypeDefinition $win32 -ErrorAction Stop | Out-Null
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

		$rect = New-Object Win32+RECT
		if (-not [Win32]::GetWindowRect($targetHwnd, [ref]$rect)) {
			throw "Failed to get window rectangle for handle $targetHwnd"
		}

		$width = $rect.Right - $rect.Left
		$height = $rect.Bottom - $rect.Top

		if ($width -le 0 -or $height -le 0) { throw "Window has invalid dimensions ($width x $height)" }

		# If the window is minimized, restore it so PrintWindow can render content.
		$restored = $false
		try {
			if ([Win32]::IsIconic($targetHwnd)) {
				[Win32]::ShowWindow($targetHwnd, 9) | Out-Null # SW_RESTORE
				Start-Sleep -Milliseconds 250
				[Win32]::SetForegroundWindow($targetHwnd) | Out-Null
				$restored = $true
			}
		}
		catch {
			# ignore restore errors and continue to attempt capture
		}
		Add-Type -AssemblyName System.Drawing
		# Attempt to capture using PrintWindow (works when window is obscured). Fallback to BitBlt.
		$srccopy = 0x00CC0020
		$PW_RENDERFULLCONTENT = 0x00000002
		$img = $null
		$hWndDC = [Win32]::GetWindowDC($targetHwnd)
		$memDC = [Win32]::CreateCompatibleDC($hWndDC)
		$hBitmap = [Win32]::CreateCompatibleBitmap($hWndDC, $width, $height)
		$oldBmp = [Win32]::SelectObject($memDC, $hBitmap)
		try {
			$pwSuccess = [Win32]::PrintWindow($targetHwnd, $memDC, $PW_RENDERFULLCONTENT)
			if (-not $pwSuccess) {
				[Win32]::BitBlt($memDC, 0, 0, $width, $height, $hWndDC, 0, 0, $srccopy) | Out-Null
			}
			$img = [System.Drawing.Image]::FromHbitmap($hBitmap)
		}
		finally {
			if ($oldBmp -ne [IntPtr]::Zero) { [Win32]::SelectObject($memDC, $oldBmp) | Out-Null }
			if ($hBitmap -ne [IntPtr]::Zero) { [Win32]::DeleteObject($hBitmap) | Out-Null }
			if ($memDC -ne [IntPtr]::Zero) { [Win32]::DeleteDC($memDC) | Out-Null }
			if ($hWndDC -ne [IntPtr]::Zero) { [Win32]::ReleaseDC($targetHwnd, $hWndDC) | Out-Null }
		}

		if ($img -eq $null) { throw "Failed to capture window image via PrintWindow/BitBlt." }

		$ext = [System.IO.Path]::GetExtension($FilePath).TrimStart('.').ToLower()
		switch ($ext) {
			'png' { $imgFmt = [System.Drawing.Imaging.ImageFormat]::Png }
			'bmp' { $imgFmt = [System.Drawing.Imaging.ImageFormat]::Bmp }
			'gif' { $imgFmt = [System.Drawing.Imaging.ImageFormat]::Gif }
			'jpg' { $imgFmt = [System.Drawing.Imaging.ImageFormat]::Jpeg }
			'jpeg' { $imgFmt = [System.Drawing.Imaging.ImageFormat]::Jpeg }
			default { $imgFmt = [System.Drawing.Imaging.ImageFormat]::Png }
		}

		$dir = [System.IO.Path]::GetDirectoryName((Resolve-Path -Path $FilePath -ErrorAction SilentlyContinue))
		if (-not $dir) { $dir = Get-Location }
		if (-not (Test-Path -Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

		$img.Save($FilePath, $imgFmt)
		$img.Dispose()

		# If we restored the window earlier, optionally minimize it again to return state
		if ($restored) {
			Start-Sleep -Milliseconds 100
			try { [Win32]::ShowWindow($targetHwnd, 6) | Out-Null } catch { }
		}

		Write-Output (Get-Item -Path $FilePath).FullName
	}
}

Export-ModuleMember -Function New-Screenshot

