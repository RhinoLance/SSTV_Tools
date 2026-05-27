# Import all Private functions first.
Get-ChildItem -Path $PSScriptRoot/Private/*.ps1 | ForEach-Object {
    . $_.FullName
}

# Import all Public functions.
Get-ChildItem -Path $PSScriptRoot/Public/*.ps1 | ForEach-Object {
    . $_.FullName
}