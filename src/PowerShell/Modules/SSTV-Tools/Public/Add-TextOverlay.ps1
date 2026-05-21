function Add-TextOverlay {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[string]$ImagePath,

		[string]$OutputPath = $null,

		[Parameter(Mandatory=$true)]
		[string]$Text,

		# Colour string. Accepts named colours, 3- or 6-digit hex, or 8-digit hex.
		# For 8-digit hex colours the format is AARRGGBB (alpha first).
		[ValidatePattern('^#?(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$|^[A-Za-z]+$')]
		[string]$Colour = '#FFFFFF',

		[int[]]$Position = @(10,10),

		[int]$Angle = 0,

		[string]$FontName = 'Arial',
		[int]$FontSize = 16,
		[ValidateSet('Regular','Bold','Italic','Underline','Strikeout','BoldItalic')]
		[string]$FontWeight = 'Bold'
	)

	if (-not (Test-Path $ImagePath)) {
		throw "Image not found: $ImagePath"
	}

	if (-not $OutputPath) {
		$ext = [IO.Path]::GetExtension($ImagePath)
		$base = [IO.Path]::GetFileNameWithoutExtension($ImagePath)
		$OutputPath = Join-Path -Path (Split-Path $ImagePath -Parent) -ChildPath "${base}_text${ext}"
	}

	Add-Type -AssemblyName System.Drawing | Out-Null

	# Load image into a memory stream so we can overwrite the original file later
	$bytes = [System.IO.File]::ReadAllBytes($ImagePath)
	$ms = New-Object System.IO.MemoryStream(,$bytes)
	try {
		$image = [System.Drawing.Image]::FromStream($ms)
		$graphics = [System.Drawing.Graphics]::FromImage($image)
		$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
		$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

		# Map FontWeight parameter to System.Drawing.FontStyle
		switch ($FontWeight.ToLower()) {
			'bold'       { $fontStyle = [System.Drawing.FontStyle]::Bold; break }
			'italic'     { $fontStyle = [System.Drawing.FontStyle]::Italic; break }
			'underline'  { $fontStyle = [System.Drawing.FontStyle]::Underline; break }
			'strikeout'  { $fontStyle = [System.Drawing.FontStyle]::Strikeout; break }
			'bolditalic' { $fontStyle = [System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic; break }
			default      { $fontStyle = [System.Drawing.FontStyle]::Bold }
		}

		$font = New-Object System.Drawing.Font($FontName, $FontSize, $fontStyle, [System.Drawing.GraphicsUnit]::Pixel)

		function ConvertTo-Color($c) {
			if ($null -eq $c) { return [System.Drawing.Color]::White }
			if ($c -match '^#?(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$') {
				$hex = $c.TrimStart('#')
				if ($hex.Length -eq 3) {
					$hex = ($hex.ToCharArray() | ForEach-Object { "$_$_" }) -join ''
				}
				if ($hex.Length -eq 6) {
					$r = [Convert]::ToInt32($hex.Substring(0,2),16)
					$g = [Convert]::ToInt32($hex.Substring(2,2),16)
					$b = [Convert]::ToInt32($hex.Substring(4,2),16)
					return [System.Drawing.Color]::FromArgb($r,$g,$b)
				}
				if ($hex.Length -eq 8) {
					$a = [Convert]::ToInt32($hex.Substring(0,2),16)
					$r = [Convert]::ToInt32($hex.Substring(2,2),16)
					$g = [Convert]::ToInt32($hex.Substring(4,2),16)
					$b = [Convert]::ToInt32($hex.Substring(6,2),16)
					return [System.Drawing.Color]::FromArgb($a,$r,$g,$b)
				}
			}
			return [System.Drawing.Color]::FromName($c)
		}

		$colorObj = ConvertTo-Color $Colour
		$brush = New-Object System.Drawing.SolidBrush($colorObj)

		$sizeF = $graphics.MeasureString($Text, $font)
		$textWidth = $sizeF.Width
		$textHeight = $sizeF.Height

		if (-not $Position -or $Position.Length -lt 2) {
			throw "Position must be an array of two integers: [left,top]"
		}

		$x = [int]$Position[0]
		$y = [int]$Position[1]

		# Compute rotated bounding box (width/height) for the text and clamp so
		# the top-left of the rotated bounding box is at the requested Position.
		$rad = $Angle * [math]::PI / 180.0
		$cosAbs = [math]::Abs([math]::Cos($rad))
		$sinAbs = [math]::Abs([math]::Sin($rad))

		$rotW = $textWidth * $cosAbs + $textHeight * $sinAbs
		$rotH = $textWidth * $sinAbs + $textHeight * $cosAbs

		$minX = 0
		$minY = 0
		$maxX = [int]([math]::Floor($image.Width - $rotW))
		$maxY = [int]([math]::Floor($image.Height - $rotH))

		if ($x -lt $minX) { $x = $minX }
		if ($y -lt $minY) { $y = $minY }
		if ($x -gt $maxX) { $x = $maxX }
		if ($y -gt $maxY) { $y = $maxY }

		# Compute center of rotated bounding box and rotate around that center
		$centerX = $x + ($rotW / 2.0)
		$centerY = $y + ($rotH / 2.0)

		$graphics.TranslateTransform($centerX, $centerY)
		if ($Angle -ne 0) { $graphics.RotateTransform($Angle) }

		$graphics.DrawString($Text, $font, $brush, -($textWidth/2), -($textHeight/2))

		# Reset transform and dispose
		$graphics.ResetTransform()
		$brush.Dispose()
		$font.Dispose()
		$graphics.Dispose()

		# Save with original format. If OutputPath equals the input path, overwrite the original file.
		if ($OutputPath -eq $ImagePath) {
			$fs = [System.IO.File]::Open($ImagePath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
			try {
				$image.Save($fs, $image.RawFormat)
			}
			finally {
				$fs.Close()
			}
		}
		else {
			$image.Save($OutputPath, $image.RawFormat)
		}

		$image.Dispose()
	}
	finally {
		$ms.Close()
	}

	return $OutputPath
}

Export-ModuleMember -Function Add-TextOverlay

