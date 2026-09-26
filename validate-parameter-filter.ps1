$registry = Get-Content -Raw (Join-Path $PSScriptRoot 'data\registry.json') | ConvertFrom-Json
$dictionary = Get-Content -Raw (Join-Path $PSScriptRoot 'data\parameter-dictionary.json') | ConvertFrom-Json
$rows = @($registry.parameterCoverage)
$report = foreach ($parameter in @($dictionary.canonical)) {
  $matches = @($rows | Where-Object {
    $_.canonical_parameter -eq $parameter.'Canonical Key' -and
    ([string]$_.parameter_supported).ToLowerInvariant() -eq 'yes'
  })
  [pscustomobject][ordered]@{
    CanonicalKey = $parameter.'Canonical Key'
    DisplayName = $parameter.'Display Name'
    CoverageRows = $matches.Count
    UniqueSources = @($matches.source_id | Sort-Object -Unique).Count
    UnsupportedRows = @($rows | Where-Object {
      $_.canonical_parameter -eq $parameter.'Canonical Key' -and
      ([string]$_.parameter_supported).ToLowerInvariant() -ne 'yes'
    }).Count
  }
}

$duplicateRows = @($rows | Group-Object source_id,canonical_parameter | Where-Object Count -gt 1)
$invalidSourceIds = @($rows | Where-Object { [string]$_.source_id -notin @($registry.sources.'Source ID') })

Write-Output "Canonical parameters: $($report.Count)"
Write-Output "Parameters with supported coverage: $(@($report | Where-Object CoverageRows -gt 0).Count)"
Write-Output "Parameters without coverage mappings: $(@($report | Where-Object CoverageRows -eq 0).Count)"
Write-Output "Duplicate source/parameter rows: $($duplicateRows.Count)"
Write-Output "Invalid source IDs: $($invalidSourceIds.Count)"

Write-Output "`nParameters without coverage mappings:"
$report | Where-Object CoverageRows -eq 0 | Format-Table CanonicalKey,DisplayName -AutoSize

Write-Output "`nSample exact checks:"
foreach ($key in @('significant_wave_height','sea_water_temperature','sea_surface_temperature','ph')) {
  $item = $report | Where-Object CanonicalKey -eq $key
  Write-Output ("{0}: {1} unique source(s)" -f $key, $item.UniqueSources)
}
