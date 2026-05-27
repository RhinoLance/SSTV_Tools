function New-SdrConsoleScreenshot {
	[CmdletBinding()]
	param(
		[Parameter(Position=0)]
		[string]$WindowName,

		[Parameter(ParameterSetName='ByName')]
		[string[]]$Exclude = @(),

		[Parameter()]
		[switch]$GetParent,

		[Parameter(Position=1)]
		[string]$FilePath = ".\screenshot.png"
	)

	Begin {
		
	}

	Process {


		$path = "C:\Users\Lance\Temp"

		$sstvSize = 324,260
		$pTopXY = 260,435
		$pBottomXY = ($pTopXY[0]+$sstvSize[0]),($pTopXY[1]+130)
		$passHeight = $pBottomXY[1] - $pTopXY[1]
		New-Screenshot -WindowName $WindowName -Exclude $Exclude -GetParent:$GetParent -FilePath "$path\screenshot.png"
		Resize-ImageCanvas -ImageFile "$path\screenshot.png" -LeftTop $pTopXY -RightBottom $pBottomXY -OutputFile "$path\snip.png"

		[console]::beep()


	}
}

Export-ModuleMember -Function New-SdrConsoleScreenshot