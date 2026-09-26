$root = $PSScriptRoot
$port = 8765

# PowerShell 7/.NET on this machine does not support HttpListener. Prefer the
# Python standard-library server, with Ruby as a fallback.
$python = Get-Command py -ErrorAction SilentlyContinue
if ($null -ne $python) {
  & $python.Source -c "import sys" 2>$null
}
if ($null -ne $python -and $LASTEXITCODE -eq 0) {
  Write-Host "Marine Observations Explorer: http://localhost:$port/"
  Write-Host 'Press Ctrl+C to stop.'
  & $python.Source -m http.server $port --directory $root
  exit $LASTEXITCODE
}

$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -ne $python) {
  & $python.Source -c "import sys" 2>$null
}
if ($null -ne $python -and $LASTEXITCODE -eq 0) {
  Write-Host "Marine Observations Explorer: http://localhost:$port/"
  Write-Host 'Press Ctrl+C to stop.'
  & $python.Source -m http.server $port --directory $root
  exit $LASTEXITCODE
}

$ruby = Get-Command ruby -ErrorAction SilentlyContinue
if ($null -ne $ruby) {
  Write-Host "Marine Observations Explorer: http://localhost:$port/"
  Write-Host 'Press Ctrl+C to stop.'
  Push-Location $root
  try { & $ruby.Source -run -e httpd . -p $port } finally { Pop-Location }
  exit $LASTEXITCODE
}

throw 'No compatible static server was found. Install Python or Ruby, then rerun serve.ps1.'
