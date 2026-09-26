Add-Type -AssemblyName System.IO.Compression.FileSystem

$xlsxPath = Join-Path $PSScriptRoot 'global_marine_observation_source_registry_with_coverage.xlsx'
$outputPath = Join-Path $PSScriptRoot 'data\registry.json'
$zip = [IO.Compression.ZipFile]::OpenRead($xlsxPath)

function Read-Entry([string]$name) {
  $entry = $zip.GetEntry($name)
  $reader = [IO.StreamReader]::new($entry.Open())
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

$sharedStrings = [xml](Read-Entry 'xl/sharedStrings.xml')
$strings = @($sharedStrings.sst.si | ForEach-Object { $_.InnerText })

function Read-SheetRecords([int]$sheetNumber) {
  $sheet = [xml](Read-Entry "xl/worksheets/sheet$sheetNumber.xml")
  $rows = @($sheet.worksheet.sheetData.row)
  if ($rows.Count -lt 2) { return @() }
  $headerCells = @{}
  foreach ($cell in @($rows[0].c)) { $headerCells[$cell.r] = if ($cell.t -eq 's') { $strings[[int]$cell.v] } else { $cell.v } }
  $columns = @($headerCells.Keys | Sort-Object { $_ -replace '\d','' })
  $headers = @($columns | ForEach-Object { $headerCells[$_] })
  $result = @()
  foreach ($row in $rows | Select-Object -Skip 1) {
    $cells = @{}
    foreach ($cell in @($row.c)) { $cells[$cell.r] = if ($cell.t -eq 's') { $strings[[int]$cell.v] } else { [string]$cell.v } }
    if ($cells.Count -eq 0) { continue }
    $record = [ordered]@{}
    for ($i = 0; $i -lt $columns.Count; $i++) {
      $columnLetter = [string]($columns[$i] -replace '\d+$', '')
      if ([string]::IsNullOrWhiteSpace($columnLetter)) { continue }
      $cellRef = "$columnLetter$($row.r)"
      if ([string]::IsNullOrWhiteSpace([string]$headers[$i])) { continue }
      $record[$headers[$i]] = if (-not [string]::IsNullOrWhiteSpace($cellRef) -and $cells.ContainsKey($cellRef)) { $cells[$cellRef] } else { '' }
    }
    $result += [pscustomobject]$record
  }
  return $result
}

$payload = [ordered]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString('o')
  sources = @(Read-SheetRecords 2)
  recipes = @(Read-SheetRecords 3)
  querySupport = @(Read-SheetRecords 4)
  taxonomy = @(Read-SheetRecords 5)
  metadataSchema = @(Read-SheetRecords 6)
  architecture = @(Read-SheetRecords 7)
  coverageIndex = @(Read-SheetRecords 9)
  parameterCoverage = @(Read-SheetRecords 10)
  coverageHarvestSpec = @(Read-SheetRecords 11)
}
New-Item -ItemType Directory -Force -Path (Split-Path $outputPath) | Out-Null
$json = $payload | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($outputPath, $json, [Text.UTF8Encoding]::new($false))
$zip.Dispose()
Write-Output "Exported $($payload.sources.Count) registry sources to $outputPath"
