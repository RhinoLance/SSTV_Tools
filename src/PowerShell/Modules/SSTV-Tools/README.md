# Install and Usage

### Install:
- **Install** with `Install-Module SSTV-Tools -AllowPrerelease`
- **Update** with `Update-Module SSTV-Tools -AllowPrerelease`


### Use

```powershell
# Import the module into the current session
Import-Module SSTV-Tools

# List all functions
(Get-Module SSTV-Tools).ExportedFunctions.Keys
```

# Functions

## `Add-ImageOverlay`

#### Parameters
- **TargetImagePath**: Path to canvas image
- **OverlayImagePath**: Path to image to overlay onto the canvas image 
- **X**: Pixel coordinate in the target image to plate the left edge of the 
overlay image.
- **Y**: Pixel coordinate in the target image to plate the top edge of the 
overlay image.
- **OutputPath**: Path to save the combined image to.

#### Returns
- **None**: Writes the composited image to `OutputPath`.

## `Add-TextOverlay`

#### Parameters
- **ImagePath**: Path to the input image.
- **OutputPath**: Optional output path for the resulting image.
- **Text**: Text to draw on the image.
- **Colour**: Text color (named color or hex value such as `#RRGGBB` or `#AARRGGBB`).
- **Position**: Two-integer array specifying text position as `[X, Y]`.
- **Angle**: Rotation angle in degrees.
- **FontName**: Font family name to use for the text.
- **FontSize**: Font size in pixels.
- **FontWeight**: Font style (`Regular`, `Bold`, `Italic`, `Underline`, `Strikeout`, `BoldItalic`).

#### Returns
- **String**: Output image path.

## `Get-ImageInfo`

#### Parameters
- **ImagePath**: Path to the image file to inspect.

#### Returns
- **PSCustomObject**: Image metadata object with `Path`, `Width`, `Height`, and `ModifiedTime`.

## `Get-WindowTitle`

#### Parameters
- **WindowName**: Window title to match (exact first, then partial match).
- **Ignore**: Optional substring to exclude matching window titles.
- **GetParent**: Return the parent/root window title when set.

#### Returns
- **String | Int32**: Window title string, or `-1` when a matching window has no title.

## `New-Screenshot`

#### Parameters
- **WindowName**: Window title to capture.
- **GetParent**: Capture the parent/root window when set.
- **FilePath**: Output path for the screenshot file.

#### Returns
- **String**: Full path to the saved screenshot.

## `Resize-ImageCanvas`

#### Parameters
- **ImageFile**: Path to the source image.
- **LeftTop**: Top-left canvas coordinate as `[X, Y]`. If negative, extra space
will be inserted to the left/top of the image.
- **RightBottom**: Bottom-right canvas coordinate as `[X, Y]`.
- **OutputFile**: Optional output path (defaults to overwriting source).
- **BackgroundColour**: Fill color for empty canvas regions.
- **Scale**: Scale the source image to fit the new canvas.
- **PreserveAspectRatio**: Preserve aspect ratio when scaling.

#### Returns
- **String**: Output image path.

## `Start-WatchFile`

#### Parameters
- **Folder**: Folder path to monitor.
- **Filter**: File filter pattern (for example `*.*` or `*.png`).
- **Action**: Script block to run when matching events occur.
- **Events**: File system events to subscribe to (`Changed`, `Created`, `Deleted`, `Renamed`).
- **DebounceSeconds**: Minimum seconds between repeated events of the same type.

#### Returns
- **PSCustomObject**: Watcher handle object to be provided to `Stop-WatchFile`.

## `Stop-WatchFile`

#### Parameters
- **Handle**: Watcher handle object returned by `Start-WatchFile`.

#### Returns
- **None**: Stops and disposes watcher resources.




# Publishing

Ensure you have set an environment variable of `PSGALLERY_API_KEY`. If you don't
already have one, generate one at 
https://www.powershellgallery.com/account/apikeys.

`./publish.ps1 -Prerelease -ApiKeyEnvVar PSGALLERY_API_KEY`