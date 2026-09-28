param([int]$ParameterLimit = 40)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$baseUrl = 'https://www.flampouris.com/marine_obs_app'
$registry = [IO.File]::ReadAllText((Join-Path $root 'global_marine_observation_source_registry_v3.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$dictionary = [IO.File]::ReadAllText((Join-Path $root 'marine_parameter_dictionary_v3.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$parameterCoverage = @($registry.parameter_coverage_v2)
$utf8 = New-Object System.Text.UTF8Encoding($false)

function HtmlEncode([object]$value) { [Net.WebUtility]::HtmlEncode([string]$value) }
function Slug([string]$value) { (($value.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-')) }
function Write-Utf8([string]$path, [string]$content) {
  $directory = Split-Path -Parent $path
  if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
  [IO.File]::WriteAllText($path, $content, $utf8)
}
function PageShell([string]$title, [string]$description, [string]$canonicalUrl, [string]$body, [hashtable]$structuredData) {
  $jsonLd = $structuredData | ConvertTo-Json -Depth 8 -Compress
  return @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>$(HtmlEncode $title)</title><meta name="description" content="$(HtmlEncode $description)"><meta name="robots" content="index,follow">
  <link rel="canonical" href="$(HtmlEncode $canonicalUrl)"><meta property="og:type" content="website"><meta property="og:title" content="$(HtmlEncode $title)"><meta property="og:description" content="$(HtmlEncode $description)"><meta property="og:url" content="$(HtmlEncode $canonicalUrl)"><meta property="og:image" content="$baseUrl/only_symbol.png">
<link rel="stylesheet" href="../../styles.css?v=seo1"><script type="application/ld+json">$jsonLd</script></head>
<body><header class="topbar"><div class="brand"><a class="help-brand-link" href="../../index.html"><span class="mark">&asymp;</span><span>Marine Observation <em>Discovery</em></span></a></div><nav class="help-nav"><a href="../../source-catalog.html">Sources</a><a href="../../canonical-dictionary.html">Parameters</a><a href="../../index.html">Search</a></nav></header>
<main class="shell seo-shell">$body</main>
<footer class="site-footer"><span>&copy; 2026 Stelios Flampouris, Ph.D.</span><nav aria-label="Footer links"><a href="https://www.flampouris.com/">flampouris.com</a><a href="mailto:stelios@flampouris.com">Contact: stelios@flampouris.com</a></nav></footer></body></html>
"@
}

$sources = @($registry.sources)
$sourceById = @{}
foreach ($source in $sources) { $sourceById[[string]$source.'Source ID'] = $source }
$sourceSlugs = @{}
foreach ($source in $sources) { $sourceSlugs[[string]$source.'Source ID'] = "$(Slug ([string]$source.'Source ID'))-$(Slug ([string]$source.Source))" }

$parameterStats = @($parameterCoverage | Group-Object canonical_parameter | ForEach-Object {
  [pscustomobject]@{ Key = $_.Name; SourceCount = @($_.Group.source_id | Sort-Object -Unique).Count }
} | Sort-Object @{Expression='SourceCount';Descending=$true}, @{Expression='Key';Descending=$false})
$selectedParameters = @($parameterStats | Select-Object -First $ParameterLimit)
$selectedKeys = @($selectedParameters.Key)

foreach ($source in $sources) {
  $id = [string]$source.'Source ID'
  $slug = $sourceSlugs[$id]
  $url = "$baseUrl/sources/$slug/"
  $mappings = @($parameterCoverage | Where-Object { [string]$_.source_id -eq $id } | Sort-Object canonical_parameter -Unique)
  $targetRows = @($registry.download_targets | Where-Object { [string]$_.source_id -eq $id })
  $parameterLinkItems = @()
  foreach ($mapping in $mappings) {
    $key = [string]$mapping.canonical_parameter
    $name = if ($mapping.display_name) { [string]$mapping.display_name } else { $key }
    if ($key -in $selectedKeys) {
      $parameterLinkItems += '<li><a href="../../parameters/{0}/">{1}</a> <code>{2}</code></li>' -f (Slug $key),(HtmlEncode $name),(HtmlEncode $key)
    } else {
      $parameterLinkItems += '<li>{0} <code>{1}</code></li>' -f (HtmlEncode $name),(HtmlEncode $key)
    }
  }
  $parameterLinks = if ($parameterLinkItems.Count) { $parameterLinkItems -join "`n" } else { '<li>No verified canonical parameter mapping is currently indexed.</li>' }
  $description = "Discover marine observations available through $($source.Source), including parameters, platforms, spatial and temporal coverage, metadata, and access methods."
  $body = @"
<nav class="breadcrumbs" aria-label="Breadcrumb"><a href="../../index.html">Marine Observation Discovery</a> / <a href="../../source-catalog.html">Sources</a> / $(HtmlEncode $source.Source)</nav>
<article class="seo-record"><p class="eyebrow">MARINE OBSERVATION SOURCE &middot; $(HtmlEncode $id)</p><h1>$(HtmlEncode $source.Source)</h1><p class="seo-lead">$(HtmlEncode $description)</p>
<dl class="seo-facts"><dt>Operator</dt><dd>$(HtmlEncode $source.Operator)</dd><dt>Role</dt><dd>$(HtmlEncode $source.Role)</dd><dt>Platforms</dt><dd>$(HtmlEncode $source.'Platform Types')</dd><dt>Observed variables</dt><dd>$(HtmlEncode $source.'Observations / Variables')</dd><dt>Spatial coverage</dt><dd>$(HtmlEncode $source.'Spatial Coverage')</dd><dt>Period</dt><dd>$(HtmlEncode $source.'Repository / Network Period')</dd><dt>Depth coverage</dt><dd>$(HtmlEncode $source.'Depth / Vertical Coverage')</dd><dt>QC and data mode</dt><dd>$(HtmlEncode $source.'QC / Data Mode')</dd><dt>Access method</dt><dd>$(HtmlEncode $source.'Recommended Download / Access Method')</dd><dt>Indexed download targets</dt><dd>$($targetRows.Count)</dd></dl>
<section><h2>Canonical parameters</h2><ul class="seo-link-list">$parameterLinks</ul></section>
<section><h2>Discovery and access</h2><p>$(HtmlEncode $source.'App Integration Notes')</p><div class="seo-actions"><a href="$(HtmlEncode $source.'Primary Access URL')" rel="noopener">Primary provider access</a><a href="$(HtmlEncode $source.'Documentation URL')" rel="noopener">Provider documentation</a><a href="../../index.html">Search this registry</a></div></section></article>
"@
  $ld = [ordered]@{
    '@context'='https://schema.org'; '@type'='DataCatalog'; '@id'="$url#catalog"; name=[string]$source.Source; description=$description; url=$url
    creator=[ordered]@{'@type'='Person';name='Stelios Flampouris';url='https://www.flampouris.com/'}
    provider=[ordered]@{'@type'='Organization';name=[string]$source.Operator}
    spatialCoverage=[string]$source.'Spatial Coverage'; temporalCoverage=[string]$source.'Repository / Network Period'
    variableMeasured=@($mappings | ForEach-Object { [string]$_.display_name } | Sort-Object -Unique)
    sameAs=@([string]$source.'Primary Access URL',[string]$source.'Documentation URL')
    isPartOf=[ordered]@{'@type'='DataCatalog';name='Global Marine Observation Source Catalog';url="$baseUrl/source-catalog.html"}
  }
  Write-Utf8 (Join-Path $root "sources/$slug/index.html") (PageShell "$($source.Source) marine observation data" $description $url $body $ld)
}

foreach ($stat in $selectedParameters) {
  $key = [string]$stat.Key
  $parameter = $dictionary.canonical_variables.PSObject.Properties[$key].Value
  if ($null -eq $parameter) { continue }
  $slug = Slug $key
  $url = "$baseUrl/parameters/$slug/"
  $mappings = @($parameterCoverage | Where-Object { [string]$_.canonical_parameter -eq $key })
  $mappedSourceIds = @($mappings.source_id | Sort-Object -Unique)
  $sourceLinkItems = @()
  foreach ($mappedSourceId in $mappedSourceIds) {
    $source = $sourceById[[string]$mappedSourceId]
    if ($source) {
      $sourceLinkItems += '<li><a href="../../sources/{0}/">{1}</a> <small>{2}</small></li>' -f $sourceSlugs[[string]$mappedSourceId],(HtmlEncode $source.Source),(HtmlEncode $source.Operator)
    }
  }
  $sourceLinks = $sourceLinkItems -join "`n"
  $displayName = [string]$parameter.display_name
  $description = [string]$parameter.definition
  $qualifiers = @($parameter.qualifiers) -join '; '
  $body = @"
<nav class="breadcrumbs" aria-label="Breadcrumb"><a href="../../index.html">Marine Observation Discovery</a> / <a href="../../canonical-dictionary.html">Parameters</a> / $(HtmlEncode $displayName)</nav>
<article class="seo-record"><p class="eyebrow">CANONICAL MARINE PARAMETER</p><h1>$(HtmlEncode $displayName)</h1><p class="seo-lead">$(HtmlEncode $description)</p>
<dl class="seo-facts"><dt>Canonical key</dt><dd><code>$(HtmlEncode $key)</code></dd><dt>Parameter family</dt><dd>$(HtmlEncode $parameter.ui_parent)</dd><dt>Scientific category</dt><dd>$(HtmlEncode $parameter.group)</dd><dt>Canonical unit</dt><dd>$(HtmlEncode $parameter.canonical_unit)</dd><dt>CF standard name / vocabulary</dt><dd>$(HtmlEncode $parameter.standard_name_or_vocab)</dd><dt>Vertical domain</dt><dd>$(HtmlEncode $parameter.vertical_domain)</dd><dt>Required qualifiers</dt><dd>$(HtmlEncode $qualifiers)</dd><dt>Merge policy</dt><dd>$(HtmlEncode $parameter.merge_policy)</dd><dt>Mapped sources</dt><dd>$($mappedSourceIds.Count)</dd></dl>
<section><h2>Marine observation sources</h2><p>The following registered sources have indexed metadata mappings for this parameter. Consult the registry details for each mapping's verification and review status.</p><ul class="seo-link-list">$sourceLinks</ul></section>
<div class="seo-actions"><a href="../../index.html">Search for $(HtmlEncode $displayName)</a><a href="$(HtmlEncode $parameter.definition_source)" rel="noopener">Authoritative definition</a><a href="../../canonical-dictionary.html">Full canonical dictionary</a></div></article>
"@
  $ld = [ordered]@{
    '@context'='https://schema.org'; '@type'='DefinedTerm'; '@id'="$url#term"; name=$displayName; description=$description; url=$url
    termCode=$key; inDefinedTermSet=[ordered]@{'@type'='DefinedTermSet';name='Marine Observation Canonical Parameter Dictionary';url="$baseUrl/canonical-dictionary.html"}
    sameAs=[string]$parameter.definition_source
  }
  Write-Utf8 (Join-Path $root "parameters/$slug/index.html") (PageShell "$displayName marine observation sources" $description $url $body $ld)
}

$lastModified = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
$urls = @("$baseUrl/", "$baseUrl/help.html", "$baseUrl/source-catalog.html", "$baseUrl/canonical-dictionary.html")
foreach ($source in $sources) {
  $sourceId = [string]$source.'Source ID'
  $urls += "$baseUrl/sources/$($sourceSlugs[$sourceId])/"
}
foreach ($selectedParameter in $selectedParameters) {
  $urls += "$baseUrl/parameters/$(Slug ([string]$selectedParameter.Key))/"
}
$urlEntries = @($urls | ForEach-Object { "  <url><loc>$([Security.SecurityElement]::Escape($_))</loc><lastmod>$lastModified</lastmod></url>" }) -join "`n"
Write-Utf8 (Join-Path $root 'sitemap.xml') "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<urlset xmlns=`"http://www.sitemaps.org/schemas/sitemap/0.9`">`n$urlEntries`n</urlset>`n"
Write-Utf8 (Join-Path $root 'robots.txt') "User-agent: *`nAllow: /`n`nSitemap: $baseUrl/sitemap.xml`n"

$sourcePages = @(Get-ChildItem (Join-Path $root 'sources') -Filter index.html -Recurse).Count
$parameterPages = @(Get-ChildItem (Join-Path $root 'parameters') -Filter index.html -Recurse).Count
if ($sourcePages -lt $sources.Count) { throw "Generated $sourcePages source pages; expected at least $($sources.Count)." }
if ($parameterPages -lt $selectedParameters.Count) { throw "Generated $parameterPages parameter pages; expected at least $($selectedParameters.Count)." }
Write-Host "Generated $($sources.Count) source pages, $($selectedParameters.Count) parameter pages, sitemap.xml, and robots.txt."
