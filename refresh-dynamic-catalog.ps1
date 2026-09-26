param(
  [string]$OutputPath = (Join-Path $PSScriptRoot 'data\dynamic-catalog.json'),
  [switch]$RequireLiveSources
)

# Dynamic catalog contract:
# one row per portal dataset parameter. Live adapters can append records to the
# seed records below without changing the frontend.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sources = Get-Content -Raw (Join-Path $PSScriptRoot 'data\sources.json') | ConvertFrom-Json
$refreshedAt = (Get-Date).ToUniversalTime().ToString('o')
$records = [System.Collections.Generic.List[object]]::new()

function Add-CatalogRecord([int]$sourceId, [string]$sourceName, [string]$datasetId, [string]$datasetTitle, [string]$parameter, [string]$unit, [string]$metadataUrl, [string]$status) {
  if ([string]::IsNullOrWhiteSpace($parameter)) { return }
  $records.Add([pscustomobject][ordered]@{
    sourceId = $sourceId
    sourceName = $sourceName
    portal = $sourceName
    datasetId = $datasetId
    datasetTitle = $datasetTitle
    parameter = $parameter
    unit = $unit
    metadataUrl = $metadataUrl
    discoveredAt = $refreshedAt
    status = $status
  })
}

# Seed every inventory source from its source/product metadata vocabulary. This
# guarantees a usable catalog while live adapters are unavailable or a portal
# requires credentials. Records are explicitly marked as seed metadata.
for ($sourceIndex = 0; $sourceIndex -lt $sources.Count; $sourceIndex++) {
  $source = $sources[$sourceIndex]
  foreach ($parameter in @($source.'Metadata Parameters')) {
    Add-CatalogRecord ([int]$source.ID) ([string]$source.'Source / Network') "source-$($source.ID)" ([string]$source.'Source / Network') ([string]$parameter) '' ([string]$source.'Metadata Source URL') 'seed'
  }
}

function Invoke-Json([string]$uri) {
  try { return Invoke-RestMethod -Uri $uri -Headers @{ Accept = 'application/json' } -TimeoutSec 60 } catch { return $null }
}

# NASA Earthdata CMR variable catalog. Set CMR_PROVIDER to a provider ID or
# comma-separated provider IDs to harvest a different Earthdata portal.
$cmrProvider = if ($env:CMR_PROVIDER) { $env:CMR_PROVIDER } else { 'POCLOUD' }
$cmr = Invoke-Json "https://cmr.earthdata.nasa.gov/search/variables.json?provider=$cmrProvider&page_size=2000"
$cmrEntries = @()
if ($null -ne $cmr -and $null -ne $cmr.PSObject.Properties['feed']) {
  $feed = $cmr.feed
  if ($null -ne $feed -and $null -ne $feed.PSObject.Properties['entry']) {
    $cmrEntries = @($feed.entry)
  }
}
if ($cmrEntries.Count -gt 0) {
  $nasaSources = @($sources | Where-Object { $_.'Source / Network' -match 'PO\.DAAC|SMAP|SWOT|CYGNSS|altimetry|GRACE|NASA' })
  foreach ($variable in $cmrEntries) {
    foreach ($source in $nasaSources) {
      Add-CatalogRecord ([int]$source.ID) ([string]$source.'Source / Network') ([string]$variable.id) ([string]$variable.name) ([string]$variable.name) ([string]$variable.units) ([string]$variable.links.href) 'live'
    }
  }
}

# Copernicus Marine catalogue adapter. The official toolbox exposes the full
# product/dataset/variable metadata through `describe`; it may require a
# configured Copernicus Marine account on the machine running this refresh.
$copernicus = Get-Command copernicusmarine -ErrorAction SilentlyContinue
if ($null -ne $copernicus) {
  try {
    $copernicusJson = (& $copernicus.Source describe --all --return-fields all 2>$null | Out-String) | ConvertFrom-Json
    $copernicusSources = @($sources | Where-Object { $_.'Source / Network' -match 'Copernicus' })
    foreach ($product in @($copernicusJson.products)) {
      foreach ($dataset in @($product.datasets)) {
        foreach ($variable in @($dataset.variables)) {
          foreach ($source in $copernicusSources) {
            Add-CatalogRecord ([int]$source.ID) ([string]$source.'Source / Network') ([string]$dataset.dataset_id) ([string]$product.title) ([string]$variable.short_name) ([string]$variable.units) ([string]$dataset.uri) 'live'
          }
        }
      }
    }
  } catch { Write-Warning "Copernicus Marine metadata refresh failed: $($_.Exception.Message)" }
}

if ($RequireLiveSources -and @($records | Where-Object status -eq 'live').Count -eq 0) {
  throw 'No live portal metadata was returned. Check network access and portal credentials.'
}

$payload = [ordered]@{
  schemaVersion = 1
  refreshedAt = $refreshedAt
  sourceCount = @($sources).Count
  coveredSourceCount = @($records.sourceId | Sort-Object -Unique).Count
  uncoveredSourceIds = @($sources | Where-Object { $_.ID -notin @($records.sourceId | Sort-Object -Unique) } | ForEach-Object { [int]$_.ID })
  liveRecordCount = @($records | Where-Object status -eq 'live').Count
  seedRecordCount = @($records | Where-Object status -eq 'seed').Count
  records = @($records)
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath) | Out-Null
$payload | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $OutputPath
Write-Output "Wrote $($records.Count) dynamic catalog records to $OutputPath"
