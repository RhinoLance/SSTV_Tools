function Repair-Filename {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        # Character to replace invalid chars with
        [string]$Replacement = '-'
    )

    # Windows invalid filename characters
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()

    # Escape regex meta-chars
    $escaped = ($invalid | ForEach-Object { [Regex]::Escape($_) }) -join ''

    # Replace invalid chars
    $clean = $Name -replace "[$escaped]", $Replacement

    # Trim leading/trailing replacement chars
    $clean = $clean.Trim($Replacement)

    return $clean
}

Export-ModuleMember -Function Repair-Filename