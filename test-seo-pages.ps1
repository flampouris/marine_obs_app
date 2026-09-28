$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$baseUrl = 'https://www.flampouris.com/marine_obs_app'
$registry = [IO.File]::ReadAllText((Join-Path $root 'global_marine_observation_source_registry_v3.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$expectedSourcePages = @($registry.sources).Count
$expectedParameterPages = 40
$expectedSitemapUrls = 4 + $expectedSourcePages + $expectedParameterPages

$sourcePages = @(Get-ChildItem (Join-Path $root 'sources') -Filter index.html -File -Recurse)
$parameterPages = @(Get-ChildItem (Join-Path $root 'parameters') -Filter index.html -File -Recurse)
if ($sourcePages.Count -ne $expectedSourcePages) { throw "Found $($sourcePages.Count) source pages; expected $expectedSourcePages." }
if ($parameterPages.Count -ne $expectedParameterPages) { throw "Found $($parameterPages.Count) parameter pages; expected $expectedParameterPages." }

[xml]$sitemap = [IO.File]::ReadAllText((Join-Path $root 'sitemap.xml'), [Text.Encoding]::UTF8)
$namespace = New-Object Xml.XmlNamespaceManager($sitemap.NameTable)
$namespace.AddNamespace('s', 'http://www.sitemaps.org/schemas/sitemap/0.9')
$sitemapUrls = @($sitemap.SelectNodes('//s:url/s:loc', $namespace) | ForEach-Object { $_.InnerText })
if ($sitemapUrls.Count -ne $expectedSitemapUrls) { throw "Found $($sitemapUrls.Count) sitemap URLs; expected $expectedSitemapUrls." }
if (@($sitemapUrls | Where-Object { -not $_.StartsWith("$baseUrl/") }).Count) { throw 'The sitemap contains a URL outside the canonical app origin.' }

$entryPages = @(
  (Join-Path $root 'index.html'),
  (Join-Path $root 'help.html'),
  (Join-Path $root 'source-catalog.html'),
  (Join-Path $root 'canonical-dictionary.html')
) + @($sourcePages.FullName) + @($parameterPages.FullName)

$canonicals = @()
$jsonLdBlocks = 0
foreach ($page in $entryPages) {
  $content = [IO.File]::ReadAllText($page, [Text.Encoding]::UTF8)
  $canonicalMatches = [regex]::Matches($content, '<link\s+rel="canonical"\s+href="([^"]+)"')
  if ($canonicalMatches.Count -ne 1) { throw "$page has $($canonicalMatches.Count) canonical links; expected exactly one." }
  $canonical = $canonicalMatches[0].Groups[1].Value
  if (-not $canonical.StartsWith("$baseUrl/")) { throw "$page has a canonical URL outside the public app origin: $canonical" }
  $canonicals += $canonical
  if ($content.Contains('flampouris.github.io/marine_obs_app')) { throw "$page contains an obsolete GitHub Pages URL." }
  if ($content -match '\u00e2|\u00c2') { throw "$page contains probable UTF-8 mojibake." }
  foreach ($match in [regex]::Matches($content, '(?s)<script\s+type="application/ld\+json">(.*?)</script>')) {
    try { $null = $match.Groups[1].Value | ConvertFrom-Json }
    catch { throw "$page contains invalid JSON-LD: $($_.Exception.Message)" }
    $jsonLdBlocks++
  }
}

$duplicateCanonicals = @($canonicals | Group-Object | Where-Object { $_.Count -gt 1 })
if ($duplicateCanonicals.Count) { throw "Found $($duplicateCanonicals.Count) duplicated canonical URLs." }
if ($jsonLdBlocks -lt (1 + $sourcePages.Count + $parameterPages.Count)) { throw "Found only $jsonLdBlocks JSON-LD blocks." }

Write-Host "SEO pages passed: $($sourcePages.Count) sources, $($parameterPages.Count) parameters, $($sitemapUrls.Count) sitemap URLs, $jsonLdBlocks JSON-LD blocks."
