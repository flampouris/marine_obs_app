param([switch]$ProbeCatalogUrls)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$registry = Get-Content -Raw (Join-Path $root 'global_marine_observation_source_registry_v3.json') | ConvertFrom-Json
$downloadCatalog = Get-Content -Raw (Join-Path $root 'marine_parameter_download_ids.json') | ConvertFrom-Json
$targets = @($downloadCatalog.download_targets)
$results = foreach ($source in $registry.sources) {
  $rows = @($targets | Where-Object source_id -eq $source.'Source ID')
  $preferred = @($rows | Where-Object preferred -eq 'Yes' | Select-Object -First 1)
  if (-not $preferred) { $preferred = @($rows | Sort-Object target_rank | Select-Object -First 1) }
  $statuses = @($rows | ForEach-Object download_ready_status | Where-Object { $_ } | Sort-Object -Unique)
  $probe = 'not run'
  if ($ProbeCatalogUrls) {
    try { $response = Invoke-WebRequest -Uri $source.'Primary Access URL' -UseBasicParsing -MaximumRedirection 3 -TimeoutSec 20; $probe = "HTTP $($response.StatusCode)" }
    catch { $probe = "ERROR: $($_.Exception.Message)" }
  }
  [pscustomobject]@{
    SourceId = $source.'Source ID'
    Source = $source.Source
    TargetCount = $rows.Count
    ExampleParameter = if ($preferred) { $preferred.display_name } else { 'not mapped in download catalog' }
    ProviderDatasetId = if ($preferred) { $preferred.provider_dataset_id } else { '' }
    Variable = if ($preferred) { $preferred.variable_selector } else { '' }
    Status = if ($statuses.Count) { $statuses -join ', ' } else { 'NO_TARGET' }
    CatalogProbe = $probe
    AccessUrl = $source.'Primary Access URL'
  }
}
$results | Sort-Object SourceId | Format-Table -Wrap -AutoSize
Write-Host "Sources represented in download catalog: $(@($results | Where-Object TargetCount -gt 0).Count) / $($results.Count)"
Write-Host "Parameter-specific download targets: $($targets.Count)"
Write-Host "Ready-status counts:"
$targets | Group-Object download_ready_status | Sort-Object Name | ForEach-Object { Write-Host ("  {0}: {1}" -f $_.Name, $_.Count) }
if ($ProbeCatalogUrls) { Write-Host 'Catalog URL probes only verify endpoint reachability; they do not confirm a parameter file download.' }
