function Get-ImageInfo {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$ImagePath
	)
	if (-not (Test-Path $ImagePath)) {
		throw "Image file not found: $ImagePath"
	}
	
	Add-Type -AssemblyName System.Drawing

	$image = [System.Drawing.Image]::FromFile($ImagePath)

	$result = $null
	try {
		$result = [PSCustomObject]@{
			Path   = $ImagePath
			Width  = [int]$image.Width
			Height = [int]$image.Height
			ModifiedTime = (Get-Item $ImagePath).LastWriteTime
		}
    } finally {
		$image.Dispose()
	}

	return $result
}

Export-ModuleMember -Function Get-ImageInfo