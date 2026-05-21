function Resize-ImageCanvas {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, Position=0)]
		[ValidateNotNullOrEmpty()]
		[string]$ImageFile,

		[Parameter(Mandatory=$true, Position=1)]
		[int[]]
		$LeftTop,

		[Parameter(Mandatory=$true, Position=2)]
		[int[]]
		$RightBottom,

		[Parameter(Mandatory=$false)]
		[string]
		$OutputFile,

		[Parameter()]
		[string]
		$BackgroundColour = '#FFFFFF',

		[Parameter()]
		[switch]
		$Scale,

		[Parameter()]
		[bool]
		$PreserveAspectRatio = $true
	)

	begin {
		if ($LeftTop.Length -ne 2 -or $RightBottom.Length -ne 2) {
			throw "`$LeftTop and `$RightBottom must be integer arrays with two elements: X and Y."
		}

		$ImageFile = (Resolve-Path $ImageFile).ProviderPath
		if (-not (Test-Path -Path $ImageFile)) {
			throw "Image file not found: $ImageFile"
		}

		try {
			Add-Type -AssemblyName System.Drawing -ErrorAction Stop
		} catch {
			# On some platforms System.Drawing may not be available; let the error bubble
			throw "Unable to load System.Drawing assembly: $_"
		}
	}

	process {
		$LeftTopX = [int]$LeftTop[0]
		$LeftTopY = [int]$LeftTop[1]
		$RightBottomX = [int]$RightBottom[0]
		$RightBottomY = [int]$RightBottom[1]

		$img = $null
		$ms = $null
		$imgStream = $null
		try {
			# Load image into memory so the source file can be overwritten safely
			$bytes = [System.IO.File]::ReadAllBytes($ImageFile)
			$ms = New-Object System.IO.MemoryStream(,$bytes)
			$imgStream = [System.Drawing.Image]::FromStream($ms)
			# Create an independent bitmap copy so the underlying stream can be disposed
			$img = New-Object System.Drawing.Bitmap($imgStream)
			$imgStream.Dispose()
			$ms.Dispose()
			$ms = $null
			$imgStream = $null
			$imgWidth = $img.Width
			$imgHeight = $img.Height

			$minX = $LeftTopX
			$minY = $LeftTopY
			$maxX = $RightBottomX
			$maxY = $RightBottomY

			$newWidth = $maxX - $minX
			$newHeight = $maxY - $minY

			if ($newWidth -le 0 -or $newHeight -le 0) {
				throw "Calculated canvas size is invalid (width=$newWidth, height=$newHeight). Ensure RightBottom is greater than LeftTop."
			}

			$offsetX = -$minX
			$offsetY = -$minY

			$newBmp = New-Object System.Drawing.Bitmap -ArgumentList $newWidth, $newHeight
			$g = [System.Drawing.Graphics]::FromImage($newBmp)
			try {
				try {
					$bgColor = [System.Drawing.ColorTranslator]::FromHtml($BackgroundColour)
				} catch {
					throw "Invalid background colour value: $BackgroundColour. Use a hex string like '#RRGGBB' or a named colour."
				}
				$g.Clear($bgColor)
				$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
				if ($Scale) {
					if ($PreserveAspectRatio) {
						$ratioSrc = $imgWidth / [double]$imgHeight
						$ratioDest = $newWidth / [double]$newHeight
						if ($ratioSrc -gt $ratioDest) {
							$targetWidth = $newWidth
							$targetHeight = [int]([math]::Round($newWidth / $ratioSrc))
						} else {
							$targetHeight = $newHeight
							$targetWidth = [int]([math]::Round($newHeight * $ratioSrc))
						}
						$destX = [int]([math]::Round(($newWidth - $targetWidth) / 2))
						$destY = [int]([math]::Round(($newHeight - $targetHeight) / 2))
						$destRect = New-Object System.Drawing.Rectangle -ArgumentList $destX, $destY, $targetWidth, $targetHeight
					} else {
						$destRect = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $newWidth, $newHeight
					}
				} else {
					$destRect = New-Object System.Drawing.Rectangle -ArgumentList $offsetX, $offsetY, $imgWidth, $imgHeight
				}
				$g.DrawImage($img, $destRect, 0, 0, $imgWidth, $imgHeight, [System.Drawing.GraphicsUnit]::Pixel)
			} finally {
				$g.Dispose()
			}

			if (-not $OutputFile) {
				$OutputFile = $ImageFile
			}

			$ext = [System.IO.Path]::GetExtension($OutputFile).ToLowerInvariant()
			switch ($ext) {
				'.png' { $format = [System.Drawing.Imaging.ImageFormat]::Png }
				'.jpg' { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
				'.jpeg' { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
				'.bmp' { $format = [System.Drawing.Imaging.ImageFormat]::Bmp }
				'.gif' { $format = [System.Drawing.Imaging.ImageFormat]::Gif }
				default { $format = [System.Drawing.Imaging.ImageFormat]::Png }
			}

			$newBmp.Save($OutputFile, $format)
			Write-Output $OutputFile

		} finally {
			if ($img) { $img.Dispose() }
			if ($ms) { $ms.Dispose() }
			if ($imgStream) { $imgStream.Dispose() }
			if ($newBmp) { $newBmp.Dispose() }
		}
	}
}

<#
.SYNOPSIS
Resizes the canvas of an image to cover the area between LeftTop and RightBottom.

.DESCRIPTION
`Resize-Image-Canvas` creates a new image with a canvas that spans the coordinates specified
by `LeftTop` and `RightBottom`. Coordinates are in pixels. If `LeftTop` contains negative
values the canvas will include empty space at the top and/or left of the original image.

.PARAMETER ImageFile
Path to the source image.

.PARAMETER LeftTop
Two-element integer array specifying the X,Y of the top-left canvas coordinate (can be negative).

.PARAMETER RightBottom
Two-element integer array specifying the X,Y of the bottom-right canvas coordinate.

.PARAMETER OutputFile
Optional path to write the new image. If omitted, the source file is overwritten.

.PARAMETER BackgroundColour
Background colour used to fill the expanded canvas. Defaults to white.

.PARAMETER Scale
If specified, the source image will be scaled to fit the new canvas instead of being placed at its original size.

.PARAMETER PreserveAspectRatio
When `-Scale` is used, controls whether the image's aspect ratio is preserved (defaults to `$true`). If set to `$false` the image is stretched to fill the canvas.

.EXAMPLE
Resize-Image-Canvas -ImageFile .\input.png -LeftTop -10,-20 -RightBottom 300,200 -OutputFile .\out.png
.EXAMPLE
# Recommended: specify coordinate arrays explicitly. Example below produces a 60x60
# image where the top and left 10 pixels are filled with the background colour.
Resize-Image-Canvas -ImageFile .\input.png -LeftTop @(-10,-10) -RightBottom @(50,50) -OutputFile .\out.png
# Result: output image will be 60x60 pixels; top and left 10px are blank (background colour).
#>

Export-ModuleMember -Function Resize-ImageCanvas