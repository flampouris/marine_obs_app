$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$html = Get-Content -Raw (Join-Path $root 'index.html')
$script = Get-Content -Raw (Join-Path $root 'app.js')

$contractMatch = [regex]::Match($script, "requiredDomIds=\[(?<ids>[^\]]+)\]")
if (-not $contractMatch.Success) { throw 'Could not find requiredDomIds in app.js.' }

$requiredIds = @([regex]::Matches($contractMatch.Groups['ids'].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
$htmlIds = @([regex]::Matches($html, 'id=["'']([^"'']+)["'']') | ForEach-Object { $_.Groups[1].Value })
$missing = @($requiredIds | Where-Object { $_ -notin $htmlIds })
$duplicates = @($htmlIds | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)

if ($missing.Count) { throw "index.html is missing required IDs: $($missing -join ', ')" }
if ($duplicates.Count) { throw "index.html contains duplicate IDs: $($duplicates -join ', ')" }

Write-Host "UI contract passed: $($requiredIds.Count) required IDs are present and all HTML IDs are unique."
