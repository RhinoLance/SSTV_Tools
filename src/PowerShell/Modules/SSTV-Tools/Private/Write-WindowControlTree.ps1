function Write-WindowControlTree {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[System.IntPtr]$WindowHandle
	)

	Initialize-Win32NativeTypes

	if ($WindowHandle -eq [System.IntPtr]::Zero) {
		throw "WindowHandle cannot be IntPtr.Zero."
	}

	$childrenByParent = @{}

	$enumChildren = [SSTVToolsWin32+EnumWindowsProc]{
		param([System.IntPtr]$childHwnd, [System.IntPtr]$lParam)

		$parentHwnd = [SSTVToolsWin32]::GetParent($childHwnd)
		if (-not $childrenByParent.ContainsKey($parentHwnd)) {
			$childrenByParent[$parentHwnd] = New-Object System.Collections.Generic.List[System.IntPtr]
		}

		$childrenByParent[$parentHwnd].Add($childHwnd)
		return $true
	}

	[SSTVToolsWin32]::EnumChildWindows($WindowHandle, $enumChildren, [System.IntPtr]::Zero) | Out-Null

	function Get-WindowNodeLine {
		param(
			[System.IntPtr]$Hwnd,
			[int]$Depth
		)

		$classSb = New-Object System.Text.StringBuilder 256
		[SSTVToolsWin32]::GetClassName($Hwnd, $classSb, $classSb.Capacity) | Out-Null
		$className = $classSb.ToString()

		$titleLen = [SSTVToolsWin32]::GetWindowTextLength($Hwnd)
		$title = ""
		if ($titleLen -gt 0) {
			$titleSb = New-Object System.Text.StringBuilder ($titleLen + 1)
			[SSTVToolsWin32]::GetWindowText($Hwnd, $titleSb, $titleSb.Capacity) | Out-Null
			$title = $titleSb.ToString()
		}

		$prefix = ("  " * $Depth) + "|- "
		$hexHandle = ('0x{0:X}' -f $Hwnd.ToInt64())

		if ([string]::IsNullOrWhiteSpace($title)) {
			return "$prefix$hexHandle [$className]"
		}

		return ('{0}{1} [{2}] "{3}"' -f $prefix, $hexHandle, $className, $title)
	}

	function Write-NodeRecursive {
		param(
			[System.IntPtr]$Parent,
			[int]$Depth
		)

		if (-not $childrenByParent.ContainsKey($Parent)) {
			return
		}

		foreach ($child in $childrenByParent[$Parent]) {
			Write-Output (Get-WindowNodeLine -Hwnd $child -Depth $Depth)
			Write-NodeRecursive -Parent $child -Depth ($Depth + 1)
		}
	}

	function Get-UiaType {
		param(
			[Parameter(Mandatory)]
			[string]$TypeName
		)

		$type = [type]::GetType("$TypeName, UIAutomationClient", $false)
		if ($null -ne $type) {
			return $type
		}

		foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
			$type = $assembly.GetType($TypeName, $false)
			if ($null -ne $type) {
				return $type
			}
		}

		return $null
	}

	function Get-UiaStaticMemberValue {
		param(
			[Parameter(Mandatory)]
			[object]$Type,
			[Parameter(Mandatory)]
			[string]$MemberName
		)

		$flags = [System.Reflection.BindingFlags]::Public -bor [System.Reflection.BindingFlags]::Static

		$property = $Type.GetProperty($MemberName, $flags)
		if ($null -ne $property) {
			return $property.GetValue($null)
		}

		$field = $Type.GetField($MemberName, $flags)
		if ($null -ne $field) {
			return $field.GetValue($null)
		}

		return $null
	}

	function Get-UiaNodeLine {
		param(
			[Parameter(Mandatory)]
			[object]$Element,
			[int]$Depth
		)

		$current = $null
		try {
			$current = $Element.Current
		}
		catch {
			$prefix = ("  " * $Depth) + "|- "
			return ('{0}UIAElement (Current unavailable: {1})' -f $prefix, $_.Exception.Message)
		}

		$prefix = ("  " * $Depth) + "|- "
		$parts = New-Object System.Collections.Generic.List[string]

		$controlTypeName = $null
		try {
			if ($null -ne $current.ControlType) {
				$controlTypeName = $current.ControlType.ProgrammaticName
			}
		}
		catch {
			$controlTypeName = $null
		}

		if (-not [string]::IsNullOrWhiteSpace($controlTypeName)) {
			$parts.Add($controlTypeName)
		}
		if (-not [string]::IsNullOrWhiteSpace($current.ClassName)) {
			$parts.Add("Class=$($current.ClassName)")
		}
		if (-not [string]::IsNullOrWhiteSpace($current.AutomationId)) {
			$parts.Add("AutomationId=$($current.AutomationId)")
		}

		$label = $parts -join ", "
		if ([string]::IsNullOrWhiteSpace($label)) {
			$label = "UIAElement"
		}

		if ([string]::IsNullOrWhiteSpace($current.Name)) {
			return "$prefix$label"
		}

		return ('{0}{1} "{2}"' -f $prefix, $label, $current.Name)
	}

	function Write-UiaNodeRecursive {
		param(
			[Parameter(Mandatory)]
			[object]$Parent,
			[Parameter(Mandatory)]
			[object]$Walker,
			[int]$Depth
		)

		$child = $Walker.GetFirstChild($Parent)
		while ($null -ne $child) {
			Write-Output (Get-UiaNodeLine -Element $child -Depth $Depth)
			Write-UiaNodeRecursive -Parent $child -Walker $Walker -Depth ($Depth + 1)
			$child = $Walker.GetNextSibling($child)
		}
	}

	function Write-UiaViewTree {
		param(
			[Parameter(Mandatory)]
			[string]$ViewName,
			[Parameter(Mandatory)]
			[object]$Root,
			[Parameter(Mandatory)]
			[object]$Walker
		)

		Write-Output ("  [{0}]" -f $ViewName)
		Write-Output (Get-UiaNodeLine -Element $Root -Depth 1)
		Write-UiaNodeRecursive -Parent $Root -Walker $Walker -Depth 2
	}

	Write-Output "Win32 Controls:"
	Write-Output (Get-WindowNodeLine -Hwnd $WindowHandle -Depth 0)
	Write-NodeRecursive -Parent $WindowHandle -Depth 1

	Write-Output ""
	Write-Output "UI Automation Elements:"

	$uiaLoaded = $false
	try {
		Add-Type -AssemblyName UIAutomationClient -ErrorAction Stop | Out-Null
		$uiaLoaded = $true
	}
	catch {
		$uiaLoaded = $false
	}

	if (-not $uiaLoaded) {
		Write-Output "  (UIAutomationClient assembly not available in this PowerShell host)"
		return
	}

	$automationElementType = Get-UiaType -TypeName "System.Windows.Automation.AutomationElement"
	$treeWalkerType = Get-UiaType -TypeName "System.Windows.Automation.TreeWalker"
	$treeScopeType = Get-UiaType -TypeName "System.Windows.Automation.TreeScope"
	$conditionType = Get-UiaType -TypeName "System.Windows.Automation.Condition"

	if ($null -eq $automationElementType -or $null -eq $treeWalkerType -or $null -eq $treeScopeType -or $null -eq $conditionType) {
		Write-Output "  (Unable to resolve UI Automation types)"
		return
	}

	try {
		$fromHandleMethod = $automationElementType.GetMethod("FromHandle", [type[]]@([System.IntPtr]))
			if ($null -eq $fromHandleMethod) {
				Write-Output "  (AutomationElement.FromHandle method not found)"
				return
			}

		$root = $fromHandleMethod.Invoke($null, @($WindowHandle))

		if ($null -eq $root) {
			Write-Output "  (No UI Automation root element found)"
			return
		}

			$controlWalker = Get-UiaStaticMemberValue -Type $treeWalkerType -MemberName "ControlViewWalker"
			$rawWalker = Get-UiaStaticMemberValue -Type $treeWalkerType -MemberName "RawViewWalker"

			if ($null -eq $controlWalker -and $null -eq $rawWalker) {
				Write-Output "  (No UIA walkers available)"
				return
			}

			if ($null -ne $controlWalker) {
				Write-UiaViewTree -ViewName "ControlView" -Root $root -Walker $controlWalker
			}
			else {
				Write-Output "  [ControlView] unavailable"
			}

			if ($null -ne $rawWalker) {
				Write-UiaViewTree -ViewName "RawView" -Root $root -Walker $rawWalker
			}
			else {
				Write-Output "  [RawView] unavailable"
			}

			$treeScopeDescendants = [Enum]::Parse($treeScopeType, "Descendants")
			$trueCondition = Get-UiaStaticMemberValue -Type $conditionType -MemberName "TrueCondition"
			if ($null -eq $trueCondition) {
				Write-Output ""
				Write-Output "  [FindAll Descendants] unavailable (TrueCondition not found)"
				return
			}

			$descendants = $root.FindAll($treeScopeDescendants, $trueCondition)
			Write-Output ""
			Write-Output ("  [FindAll Descendants] Count={0}" -f $descendants.Count)
			for ($i = 0; $i -lt $descendants.Count; $i++) {
				Write-Output (Get-UiaNodeLine -Element $descendants.Item($i) -Depth 2)
			}
	}
	catch {
		Write-Output ('  (Failed to enumerate UI Automation tree: {0})' -f $_.Exception.Message)
	}
}
