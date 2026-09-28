$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$html = Get-Content -Raw (Join-Path $root 'index.html')
$script = Get-Content -Raw (Join-Path $root 'app.js')

$contractMatch = [regex]::Match($script, "requiredDomIds=\[(?<ids>[^\]]+)\]")
if (-not $contractMatch.Success) { throw 'Could not find requiredDomIds in app.js.' }

$declaredIds = @([regex]::Matches($contractMatch.Groups['ids'].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$referencedIds = @([regex]::Matches($script, "\$\('([^']+)'\)") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$htmlIds = @([regex]::Matches($html, 'id=["'']([^"'']+)["'']') | ForEach-Object { $_.Groups[1].Value })
$undeclared = @($referencedIds | Where-Object { $_ -notin $declaredIds })
$missing = @($referencedIds | Where-Object { $_ -notin $htmlIds })
$duplicates = @($htmlIds | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)

if ($undeclared.Count) { throw "app.js uses literal element IDs not listed in requiredDomIds: $($undeclared -join ', ')" }
if ($missing.Count) { throw "index.html is missing IDs referenced by app.js: $($missing -join ', ')" }
if ($duplicates.Count) { throw "index.html contains duplicate IDs: $($duplicates -join ', ')" }

Write-Host "UI contract passed: all $($referencedIds.Count) literal element references in app.js exist in index.html and all HTML IDs are unique."
