# Get path from arguments
param(
	[string]$ImagePath = "C:\Ham\MMSSTV\History\latest.jpg",
	[string]$TempWorkingDir = ([System.IO.Path]::GetTempPath() + "\SSTVPrep"),
	[string]$ConfigPath = ".\config.json"
)

Remove-Module SSTV-Tools -Force -ErrorAction SilentlyContinue
Import-Module SSTV-Tools\

$config = @{}
if( (Test-Path $ConfigPath)) {
	Write-Host "Runner config loaded from $ConfigPath"
	$config = Get-Content -Path $ConfigPath | ConvertFrom-Json
}
else {
	$config.tempWorkingDir = [System.IO.Path]::GetTempPath() + "/SSTVPrep"
}

if( -not (Test-Path $ImagePath)) {
	Write-Host "Image file not found: $ImagePath"
	exit 1
}

$path = $TempWorkingDir
if( -not (Test-Path $path)) {
	New-Item -Path $path -ItemType Directory -Force | Out-Null
}

$windows = @{
	PASS = $config.windows?.PASS ?? "Automatic Schedule"
	TRACKER = $config.windows?.TRACKER ?? "Tracker"
	WATERFALL = $config.windows?.WATERFALL ?? "Receivers"
}

try{
Write-Host "Processing image: $ImagePath"
# Prepare the sstv image
	Write-Host "Preparing SSTV image"

	# Add a border to the latest image.
	$originalImageDetail = Get-ImageInfo -ImagePath $ImagePath
	$borderWidth = 2
	$borderCoords = ($originalImageDetail.Width + $borderWidth), ($originalImageDetail.Height + $borderWidth)
	$sstvSize = ($originalImageDetail.Width + ($borderWidth*2)), ($originalImageDetail.Height + ($borderWidth*2))
 	Resize-ImageCanvas -ImageFile "$ImagePath" -LeftTop -$borderWidth,-$borderWidth -RightBottom $borderCoords -OutputFile "$path\master.png" -BackgroundColour "#000"
	
# Pass image prep
	Write-Host "Preparing satellite pass screen capture"
	$pTopXY = 250,433
	$pBottomXY = ($pTopXY[0]+$sstvSize[0]),($pTopXY[1]+130)
	$passHeight = $pBottomXY[1] - $pTopXY[1]
	New-Screenshot -WindowName $windows.PASS -GetParent -FilePath "$path\sat_path.png"
 	Resize-ImageCanvas -ImageFile "$path\sat_path.png" -LeftTop $pTopXY -RightBottom $pBottomXY -OutputFile "$path\sat_path_resized.png"
 
# Tracker image prep
	Write-Host "Preparing tracker screen capture"
	New-Screenshot -WindowName $windows.TRACKER -FilePath "$path\tracker.png"
	
	$imageDetail = Get-ImageInfo -ImagePath "$path\tracker.png"
	
	$cropStartXY = 0,27
	$cropStopXY = ($imageDetail.Width, $imageDetail.Height)
	$scopRatio = $imageDetail.Width / ($imageDetail.Height - 27)
 	$scaleStartXY = 0,0
 	$scaleStopXY = ($sstvSize[0], [int]($sstvSize[0] / $scopRatio))
 	$trackerHeight = $scaleStopXY[1] - $scaleStartXY[1]
 
	# crop then scale
	Resize-ImageCanvas -ImageFile "$path\tracker.png" -LeftTop $cropStartXY -RightBottom $cropStopXY -OutputFile "$path\tracker_resized.png"
	Resize-ImageCanvas -ImageFile "$path\tracker_resized.png" -LeftTop $scaleStartXY -RightBottom $scaleStopXY -OutputFile "$path\tracker_resized.png" -Scale

# Receiver image prep
	Write-Host "Preparing waterfall screen capture"
	New-Screenshot -WindowName $windows.WATERFALL -FilePath "$path\waterfall.png"
 		
	$topOffset = 10;  # Centre + offset to capture the freq bar.
	$leftOffset = 30;
	$targetSize = (100,90)
	$imageDetail = Get-ImageInfo -ImagePath "$path\waterfall.png"
	$startX = ($imageDetail.Width / 2) + ($leftOffset /2) - ($targetSize[0] / 2)
	$startY = ($imageDetail.Height /2) - $topOffset

	$rTopXY = $startX, $startY
	$rBottomXY = ($startX + $targetSize[0]), ($startY + $targetSize[1])

	$waterfallHeight = $targetSize[1] + 2 # Add 2px for border
	Resize-ImageCanvas -ImageFile "$path\waterfall.png" -LeftTop $rTopXY -RightBottom $rBottomXY -OutputFile "$path\waterfall_resized.png"
	# Add border to waterfall image
 	Resize-ImageCanvas -ImageFile "$path\waterfall_resized.png" -LeftTop 0,-2 -RightBottom ($targetSize[0]+2),($targetSize[1]) -OutputFile "$path\waterfall_resized.png"

# Final compose
	Write-Host "Preparing final image's canvas"
	$margin = 0
	$pathTop = $sstvSize[1] + 5
 	$trackerTop = $pathTop + $passHeight
	$waterfallTop = $trackerTop - $waterfallHeight
	$canvasSize = ($sstvSize[0], ($trackerTop + $trackerHeight))
	
	# Expand the canvas to fit the additional images
 	Resize-ImageCanvas -ImageFile "$path\master.png" -LeftTop 0,0 -RightBottom $canvasSize -OutputFile "$path\master.png" -BackgroundColour "#FFF"

# add overlays
 	Write-Host "Ovelaying images"
	Add-ImageOverlay -TargetImagePath "$path\master.png" -OverlayImagePath "$path\sat_path_resized.png" -X $margin -Y $pathTop -OutputPath "$path\master.png"
 	Add-ImageOverlay -TargetImagePath "$path\master.png" -OverlayImagePath "$path\tracker_resized.png" -X $margin -Y $trackerTop -OutputPath "$path\master.png"
	Add-ImageOverlay -TargetImagePath "$path\master.png" -OverlayImagePath "$path\waterfall_resized.png" -X $margin -Y $waterfallTop -OutputPath "$path\master.png"

	# Add border to the final image
	$outerBorderWidth = 5
	$canvasSize = ($sstvSize[0] + ($outerBorderWidth)), ($canvasSize[1] + ($outerBorderWidth))
 	Resize-ImageCanvas -ImageFile "$path\master.png" -LeftTop -$outerBorderWidth,-$outerBorderWidth -RightBottom $canvasSize -OutputFile "$path\master.png" -BackgroundColour "#FFF"

# add text overlays	
	Write-Host "Adding text overlays"	

	# date/time
	#Get date from originalImageDetail.ModifiedTime as UTC
	$utcNow = $originalImageDetail.ModifiedTime.ToUniversalTime()
	$date = $utcNow.ToString("dd MMM yyyy")
	$time = $utcNow.ToString("HH:mm 'UTC'")
	$fontSize = 12
	$line1 = $pathTop + 9
	$line2 = $line1 + $fontSize + 2
	Add-TextOverlay -ImagePath "$path\master.png" -Text $date -Colour "#CCC" -FontSize $fontSize -Position @(8,$line1) -OutputPath "$path\written.png"
	Add-TextOverlay -ImagePath "$path\written.png" -Text $time -Colour "#CCC" -FontSize $fontSize -Position @(8,$line2) -OutputPath "$path\written.png"

	# watermark
	$wmFontSize = 40
	$wmXY = 90,465
	Add-TextOverlay -ImagePath "$path\written.png" -Text "VK7TO" -Colour "#22888888" -FontSize $wmFontSize -FontWeight Bold -Position $wmXY -OutputPath "$path\written.png"

# all done, move the final image to the original location
	Write-Host "Moving final image to destination"
	
	$destName = $utcNow.ToString("yyyyMMdd_HHmmss") + "Z.png"
	Move-Item -Path "$path\written.png" -Destination "$path\$destName" -Force

	Write-Host "Final composition was saved to: $path\$destName"

	Write-Host "Uploading to server"
	scp $path\$destName outerplanet@rhinosw.com:~/conryclan.com/projects/satellite/sstv/archive/

	Write-Host "Done!"
}
catch {
	Write-Host "Error processing image: $_"
	exit 1
}