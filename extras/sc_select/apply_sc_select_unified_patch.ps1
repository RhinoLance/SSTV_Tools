param(
  [string]$BinaryPath = "c:\users\lance\temp\sc_select_2.mmw",
  [string]$PatchFile = "c:\Users\lance\Temp\sc_select_2_unified_patch.json",
  [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

function HexToBytes([string]$hex) {
  $clean = ($hex -replace '\s+', '').ToUpperInvariant()
  if ($clean.Length % 2 -ne 0) { throw "Invalid hex string length: $hex" }
  $bytes = New-Object byte[] ($clean.Length / 2)
  for ($i = 0; $i -lt $bytes.Length; $i++) {
    $bytes[$i] = [Convert]::ToByte($clean.Substring($i * 2, 2), 16)
  }
  return $bytes
}

function ParseHexToUInt32([string]$value) {
  $clean = $value.Trim()
  if ($clean.StartsWith('0x') -or $clean.StartsWith('0X')) { $clean = $clean.Substring(2) }
  return [Convert]::ToUInt32($clean, 16)
}

function SetBytes([byte[]]$arr, [int]$offset, [byte[]]$data) {
  [Array]::Copy($data, 0, $arr, $offset, $data.Length)
}

function GetUInt16([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt16($arr, $off) }
function GetUInt32([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt32($arr, $off) }
function SetUInt16([byte[]]$arr, [int]$off, [UInt16]$v) { SetBytes $arr $off ([BitConverter]::GetBytes($v)) }
function SetUInt32([byte[]]$arr, [int]$off, [UInt32]$v) { SetBytes $arr $off ([BitConverter]::GetBytes($v)) }

if (-not (Test-Path -LiteralPath $BinaryPath)) { throw "Binary not found: $BinaryPath" }
if (-not (Test-Path -LiteralPath $PatchFile)) { throw "Patch file not found: $PatchFile" }

if (-not $NoBackup) {
  $backup = "$BinaryPath.bak"
  if (-not (Test-Path -LiteralPath $backup)) {
    Copy-Item -LiteralPath $BinaryPath -Destination $backup -Force
  }
}

$patch = Get-Content -LiteralPath $PatchFile -Raw | ConvertFrom-Json
[byte[]]$bytes = [System.IO.File]::ReadAllBytes($BinaryPath)

# PE parse
$e_lfanew = [BitConverter]::ToInt32($bytes, 0x3C)
if ([BitConverter]::ToUInt32($bytes, $e_lfanew) -ne 0x4550) { throw 'Not a PE file' }
$numberOfSections = GetUInt16 $bytes ($e_lfanew + 6)
$sizeOpt = GetUInt16 $bytes ($e_lfanew + 20)
$optStart = $e_lfanew + 24
$magic = GetUInt16 $bytes $optStart
if ($magic -ne 0x10b) { throw "Expected PE32 (0x10b), got 0x$('{0:X}' -f $magic)" }
$sectionAlignment = GetUInt32 $bytes ($optStart + 32)
$fileAlignment = GetUInt32 $bytes ($optStart + 36)
$sectionTable = $optStart + $sizeOpt

function AlignUp([uint32]$v, [uint32]$a) {
  if ($a -eq 0) { return $v }
  return [uint32]((($v + $a - 1) / $a) * $a)
}

# Build section list
$sections = @()
for ($i = 0; $i -lt $numberOfSections; $i++) {
  $o = $sectionTable + (40 * $i)
  $name = [Text.Encoding]::ASCII.GetString($bytes[$o..($o+7)]).Trim([char]0)
  $vs = GetUInt32 $bytes ($o + 8)
  $va = GetUInt32 $bytes ($o + 12)
  $rs = GetUInt32 $bytes ($o + 16)
  $rp = GetUInt32 $bytes ($o + 20)
  $sections += [PSCustomObject]@{ Off=$o; Name=$name; VS=$vs; VA=$va; RS=$rs; RP=$rp }
}

# Ensure .adev section exists and matches requested layout
$secName = [string]$patch.section.name
$targetVA = ParseHexToUInt32 ([string]$patch.section.virtualAddress)
$targetVS = ParseHexToUInt32 ([string]$patch.section.virtualSize)
$targetRP = ParseHexToUInt32 ([string]$patch.section.rawPointer)
$targetRS = ParseHexToUInt32 ([string]$patch.section.rawSize)
$targetCh = ParseHexToUInt32 ([string]$patch.section.characteristics)
$targetSizeImage = ParseHexToUInt32 ([string]$patch.section.sizeOfImage)

$adev = $sections | Where-Object { $_.Name -eq $secName } | Select-Object -First 1
if (-not $adev) {
  $newHdr = $sectionTable + (40 * $numberOfSections)
  if (($newHdr + 40) -gt 0x1000) { throw 'No room in headers for new section entry' }

  # Expand file as needed for target raw region.
  $neededLen = [int]($targetRP + $targetRS)
  if ($bytes.Length -lt $neededLen) {
    $nb = New-Object byte[] $neededLen
    [Array]::Copy($bytes, 0, $nb, 0, $bytes.Length)
    $bytes = $nb
  }

  $nameBytes = [Text.Encoding]::ASCII.GetBytes($secName)
  $nameField = New-Object byte[] 8
  [Array]::Copy($nameBytes, 0, $nameField, 0, [Math]::Min($nameBytes.Length, 8))
  SetBytes $bytes $newHdr $nameField
  SetUInt32 $bytes ($newHdr + 8)  $targetVS
  SetUInt32 $bytes ($newHdr + 12) $targetVA
  SetUInt32 $bytes ($newHdr + 16) $targetRS
  SetUInt32 $bytes ($newHdr + 20) $targetRP
  SetUInt32 $bytes ($newHdr + 24) 0
  SetUInt32 $bytes ($newHdr + 28) 0
  SetUInt16 $bytes ($newHdr + 32) 0
  SetUInt16 $bytes ($newHdr + 34) 0
  SetUInt32 $bytes ($newHdr + 36) $targetCh

  SetUInt16 $bytes ($e_lfanew + 6) ([uint16]($numberOfSections + 1))
  SetUInt32 $bytes ($optStart + 56) $targetSizeImage
}
else {
  # Normalize existing .adev values to target.
  $o = [int]$adev.Off
  SetUInt32 $bytes ($o + 8)  $targetVS
  SetUInt32 $bytes ($o + 12) $targetVA
  SetUInt32 $bytes ($o + 16) $targetRS
  SetUInt32 $bytes ($o + 20) $targetRP
  SetUInt32 $bytes ($o + 36) $targetCh
  SetUInt32 $bytes ($optStart + 56) $targetSizeImage

  $neededLen = [int]($targetRP + $targetRS)
  if ($bytes.Length -lt $neededLen) {
    $nb = New-Object byte[] $neededLen
    [Array]::Copy($bytes, 0, $nb, 0, $bytes.Length)
    $bytes = $nb
  }
}

# Apply byte patches idempotently: current must match old or new.
$changed = 0
foreach ($p in $patch.patches) {
  $off = [int](ParseHexToUInt32 ([string]$p.offset))
  $old = HexToBytes ([string]$p.old)
  $new = HexToBytes ([string]$p.new)
  if ($old.Length -ne $new.Length) {
    throw "Length mismatch in patch '$($p.label)' at offset $($p.offset)"
  }

  $cur = New-Object byte[] $old.Length
  [Array]::Copy($bytes, $off, $cur, 0, $old.Length)

  $isOld = $true
  $isNew = $true
  for ($i = 0; $i -lt $old.Length; $i++) {
    if ($cur[$i] -ne $old[$i]) { $isOld = $false }
    if ($cur[$i] -ne $new[$i]) { $isNew = $false }
  }

  if (-not ($isOld -or $isNew)) {
    $curHex = ($cur | ForEach-Object { '{0:X2}' -f $_ }) -join ''
    throw "Patch verify failed at $($p.offset) ($($p.label)): found $curHex"
  }

  if ($isOld) {
    SetBytes $bytes $off $new
    $changed++
  }
}

[System.IO.File]::WriteAllBytes($BinaryPath, $bytes)

# Final verification summary
[byte[]]$out = [System.IO.File]::ReadAllBytes($BinaryPath)
Write-Output ("Applied patch set: {0}" -f $patch.name)
Write-Output ("Changed entries this run: {0}" -f $changed)
Write-Output ("File length: 0x{0:X}" -f $out.Length)

foreach ($p in $patch.patches) {
  $off = [int](ParseHexToUInt32 ([string]$p.offset))
  $len = (HexToBytes ([string]$p.new)).Length
  $cur = New-Object byte[] $len
  [Array]::Copy($out, $off, $cur, 0, $len)
  $curHex = ($cur | ForEach-Object { '{0:X2}' -f $_ }) -join ''
  Write-Output ("{0} @ {1}: {2}" -f $p.label, $p.offset, $curHex)
}
