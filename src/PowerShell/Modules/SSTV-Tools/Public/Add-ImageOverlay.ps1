function Add-ImageOverlay {
    <#
    .SYNOPSIS
        Overlays one image on top of another at specified coordinates.
    
    .DESCRIPTION
        Takes a target image and overlays an image on top of it at the specified insertion coordinates.
    
    .PARAMETER TargetImagePath
        The path to the base/target image file.
    
    .PARAMETER OverlayImagePath
        The path to the image to overlay on top of the target image.
    
    .PARAMETER X
        The X coordinate (horizontal position) where the overlay image should be inserted.
    
    .PARAMETER Y
        The Y coordinate (vertical position) where the overlay image should be inserted.
    
    .PARAMETER OutputPath
        The path where the resulting overlaid image will be saved.
    
    .EXAMPLE
        Add-Overlay -TargetImagePath "C:\Images\base.jpg" -OverlayImagePath "C:\Images\overlay.png" -X 100 -Y 50 -OutputPath "C:\Images\result.jpg"
    #>
    
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetImagePath,
        
        [Parameter(Mandatory = $true)]
        [string]$OverlayImagePath,
        
        [Parameter(Mandatory = $true)]
        [int]$X,
        
        [Parameter(Mandatory = $true)]
        [int]$Y,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    # Load images and ensure System.Drawing is available
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    } catch {
        [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
    }

    # Load images into memory streams so the source files can be overwritten safely
    $targetImage = $null
    $overlayImage = $null
    try {
        $targetBytes = [System.IO.File]::ReadAllBytes($TargetImagePath)
        $targetMs = New-Object System.IO.MemoryStream(,$targetBytes)
        $targetStreamImg = [System.Drawing.Image]::FromStream($targetMs)
        $targetImage = New-Object System.Drawing.Bitmap($targetStreamImg)
        $targetStreamImg.Dispose()
        $targetMs.Dispose()

        $overlayBytes = [System.IO.File]::ReadAllBytes($OverlayImagePath)
        $overlayMs = New-Object System.IO.MemoryStream(,$overlayBytes)
        $overlayStreamImg = [System.Drawing.Image]::FromStream($overlayMs)
        $overlayImage = New-Object System.Drawing.Bitmap($overlayStreamImg)
        $overlayStreamImg.Dispose()
        $overlayMs.Dispose()
    } catch {
        if ($targetImage) { $targetImage.Dispose() }
        if ($overlayImage) { $overlayImage.Dispose() }
        throw
    }

    try {
        # Make overlay use the same DPI as the target to avoid implicit scaling
        $overlayImage.SetResolution([float]$targetImage.HorizontalResolution, [float]$targetImage.VerticalResolution)

        # Create graphics object from target image and draw using pixel units
        $graphics = [System.Drawing.Graphics]::FromImage($targetImage)
        try {
            $graphics.PageUnit = [System.Drawing.GraphicsUnit]::Pixel
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

            # Draw using an explicit destination rectangle in pixels to avoid DPI/unit ambiguity
            $destRect = New-Object System.Drawing.Rectangle -ArgumentList $X, $Y, $overlayImage.Width, $overlayImage.Height
            $graphics.DrawImage($overlayImage, $destRect, 0, 0, $overlayImage.Width, $overlayImage.Height, [System.Drawing.GraphicsUnit]::Pixel)
        } finally {
            $graphics.Dispose()
        }

        # Save result using format inferred from OutputPath
        $ext = [System.IO.Path]::GetExtension($OutputPath).ToLowerInvariant()
        switch ($ext) {
            '.png' { $format = [System.Drawing.Imaging.ImageFormat]::Png }
            '.jpg' { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
            '.jpeg' { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
            '.bmp' { $format = [System.Drawing.Imaging.ImageFormat]::Bmp }
            '.gif' { $format = [System.Drawing.Imaging.ImageFormat]::Gif }
            default { $format = [System.Drawing.Imaging.ImageFormat]::Png }
        }

        # Save result into an in-memory stream so we never create temporary files.
        $outMs = New-Object System.IO.MemoryStream
        try {
            $targetImage.Save($outMs, $format)
            $bytes = $outMs.ToArray()
        } finally {
            $outMs.Dispose()
        }

        # Write the bytes to the requested output path (can overwrite inputs safely)
        [System.IO.File]::WriteAllBytes($OutputPath, $bytes)
    } finally {
        $targetImage.Dispose()
        $overlayImage.Dispose()
    }
}

Export-ModuleMember -Function Add-ImageOverlay