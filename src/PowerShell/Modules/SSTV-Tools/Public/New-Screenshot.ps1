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
		Initialize-Win32NativeTypes
	}

	Process {
		
		$hwnd = Get-WindowHandleByName -WindowName $WindowName

		if ($hwnd -eq [IntPtr]::Zero) {
			throw "Window with name '$WindowName' not found."
		}

		$targetHwnd = [IntPtr]::Zero
		
		if( $GetParent.IsPresent ) {
			$targetHwnd = [SSTVToolsWin32]::GetParent($hwnd)
			if( $targetHwnd -eq [IntPtr]::Zero) {
				$targetHwnd = [SSTVToolsWin32]::GetAncestor($hwnd, 2) # Get root ancestor
			}
			if( $targetHwnd -eq [IntPtr]::Zero) {
				throw "Failed to get parent window handle for child window $hwnd."
			}
		} else {
			$targetHwnd = $hwnd
		}

		$rect = New-Object SSTVToolsWin32+RECT
		if (-not [SSTVToolsWin32]::GetWindowRect($targetHwnd, [ref]$rect)) {
			throw "Failed to get window rectangle for handle $targetHwnd"
		}

		$width = $rect.Right - $rect.Left
		$height = $rect.Bottom - $rect.Top

		if ($width -le 0 -or $height -le 0) { throw "Window has invalid dimensions ($width x $height)" }

		# If the window is minimized, restore it so PrintWindow can render content.
		$restored = $false
		try {
			if ([SSTVToolsWin32]::IsIconic($targetHwnd)) {
				[SSTVToolsWin32]::ShowWindow($targetHwnd, 9) | Out-Null # SW_RESTORE
				Start-Sleep -Milliseconds 250
				[SSTVToolsWin32]::SetForegroundWindow($targetHwnd) | Out-Null
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
		$hWndDC = [SSTVToolsWin32]::GetWindowDC($targetHwnd)
		$memDC = [SSTVToolsWin32]::CreateCompatibleDC($hWndDC)
		$hBitmap = [SSTVToolsWin32]::CreateCompatibleBitmap($hWndDC, $width, $height)
		$oldBmp = [SSTVToolsWin32]::SelectObject($memDC, $hBitmap)
		try {
			$pwSuccess = [SSTVToolsWin32]::PrintWindow($targetHwnd, $memDC, $PW_RENDERFULLCONTENT)
			if (-not $pwSuccess) {
				[SSTVToolsWin32]::BitBlt($memDC, 0, 0, $width, $height, $hWndDC, 0, 0, $srccopy) | Out-Null
			}
			$img = [System.Drawing.Image]::FromHbitmap($hBitmap)
		}
		finally {
			if ($oldBmp -ne [IntPtr]::Zero) { [SSTVToolsWin32]::SelectObject($memDC, $oldBmp) | Out-Null }
			if ($hBitmap -ne [IntPtr]::Zero) { [SSTVToolsWin32]::DeleteObject($hBitmap) | Out-Null }
			if ($memDC -ne [IntPtr]::Zero) { [SSTVToolsWin32]::DeleteDC($memDC) | Out-Null }
			if ($hWndDC -ne [IntPtr]::Zero) { [SSTVToolsWin32]::ReleaseDC($targetHwnd, $hWndDC) | Out-Null }
		}

		if ($null -eq $img) { throw "Failed to capture window image via PrintWindow/BitBlt." }

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
			try { [SSTVToolsWin32]::ShowWindow($targetHwnd, 6) | Out-Null } catch { }
		}

		Write-Output (Get-Item -Path $FilePath).FullName
	}
}

Export-ModuleMember -Function New-Screenshot

