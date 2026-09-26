Add-Type -AssemblyName System.IO.Compression.FileSystem

$xlsxPath = Join-Path $PSScriptRoot 'marine_parameter_dictionary.xlsx'
$outputPath = Join-Path $PSScriptRoot 'data\parameter-dictionary.json'
$zip = [IO.Compression.ZipFile]::OpenRead($xlsxPath)
function Read-Entry([string]$name){$e=$zip.GetEntry($name);$sr=[IO.StreamReader]::new($e.Open());try{return $sr.ReadToEnd()}finally{$sr.Dispose()}}
$shared=[xml](Read-Entry 'xl/sharedStrings.xml');$strings=@($shared.sst.si|ForEach-Object{$_.InnerText})
function Read-Sheet([int]$n){
  $doc=[xml](Read-Entry "xl/worksheets/sheet$n.xml");$rows=@($doc.worksheet.sheetData.row);if($rows.Count -lt 2){return @()}
  $header=@{};foreach($c in @($rows[0].c)){$header[$c.r]=if($c.t -eq 's'){$strings[[int]$c.v]}else{[string]$c.v}}
  $cols=@($header.Keys|Sort-Object{$_ -replace '\d',''});$out=@()
  foreach($row in $rows|Select-Object -Skip 1){$cells=@{};foreach($c in @($row.c)){$cells[$c.r]=if($c.t -eq 's'){$strings[[int]$c.v]}else{[string]$c.v}};$obj=[ordered]@{}
    for($i=0;$i -lt $cols.Count;$i++){ $letter=[string]($cols[$i]-replace '\d+$','');if(!$letter){continue};$ref="$letter$($row.r)";$key=$header[$cols[$i]];if($key){$obj[$key]=if($cells.ContainsKey($ref)){$cells[$ref]}else{''}} }
    if($obj.Count){$out+=[pscustomobject]$obj}
  };return $out
}
$payload=[ordered]@{generatedAt=(Get-Date).ToUniversalTime().ToString('o');canonical=@(Read-Sheet 2);aliases=@(Read-Sheet 3);metadata=@(Read-Sheet 4);metadataAliases=@(Read-Sheet 5);doNotMerge=@(Read-Sheet 6);sourceCoverage=@(Read-Sheet 7);suggestedUI=@(Read-Sheet 8)}
New-Item -ItemType Directory -Force -Path (Split-Path $outputPath)|Out-Null
[IO.File]::WriteAllText($outputPath,($payload|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false));$zip.Dispose()
Write-Output "Exported $($payload.canonical.Count) canonical parameters and $($payload.aliases.Count) alias rules to $outputPath"
