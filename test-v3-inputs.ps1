$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$registryName = 'global_marine_observation_source_registry_v3.json'
$dictionaryName = 'marine_parameter_dictionary_v3.json'
$expectedRuntimeInputs = @($registryName, $dictionaryName) | Sort-Object

$appScript = [IO.File]::ReadAllText((Join-Path $root 'app.js'), [Text.Encoding]::UTF8)
$helpScript = [IO.File]::ReadAllText((Join-Path $root 'help.js'), [Text.Encoding]::UTF8)
$runtimeInputs = @(
  [regex]::Matches($appScript, "loadJson\('([^']+\.json)'\)") | ForEach-Object { $_.Groups[1].Value }
  [regex]::Matches($helpScript, "fetch\('([^']+\.json)'\)") | ForEach-Object { $_.Groups[1].Value }
) | Sort-Object -Unique

if (Compare-Object $expectedRuntimeInputs $runtimeInputs) {
  throw "Runtime JSON inputs are not the exclusive v3 set. Found: $($runtimeInputs -join ', ')"
}

$buildFiles = @('app.js', 'help.js', 'generate-seo-pages.ps1', 'test-download-examples.ps1', 'debug-console.html', 'diagnostics.html')
$forbiddenInputs = @('marine_parameter_dictionary_v2.json', 'marine_parameter_coverage_v2.json', 'marine_parameter_download_ids.json', 'global_marine_observation_source_registry_v2.json')
foreach ($file in $buildFiles) {
  $content = [IO.File]::ReadAllText((Join-Path $root $file), [Text.Encoding]::UTF8)
  foreach ($forbidden in $forbiddenInputs) {
    if ($content.Contains($forbidden)) { throw "$file still references forbidden runtime/build input $forbidden." }
  }
}

$registry = [IO.File]::ReadAllText((Join-Path $root $registryName), [Text.Encoding]::UTF8) | ConvertFrom-Json
$dictionary = [IO.File]::ReadAllText((Join-Path $root $dictionaryName), [Text.Encoding]::UTF8) | ConvertFrom-Json
if (@($registry.sources).Count -ne 42) { throw 'The v3 registry does not contain 42 sources.' }
if (@($registry.parameter_coverage_v2).Count -ne 368) { throw 'The v3 registry does not contain 368 parameter mappings.' }
if (@($registry.download_targets).Count -ne 259) { throw 'The v3 registry does not contain 259 download targets.' }
if (@($dictionary.canonical_variables.PSObject.Properties).Count -ne 96) { throw 'The v3 dictionary does not contain 96 canonical parameters.' }
if ([string]$dictionary.version -ne 'v3') { throw 'The canonical dictionary is not marked as v3.' }

Write-Host "V3 inputs passed: 2 runtime files, 42 sources, 96 parameters, 368 mappings, and 259 download targets."
