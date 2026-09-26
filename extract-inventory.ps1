Add-Type -AssemblyName System.IO.Compression.FileSystem

$xlsxPath = Join-Path $PSScriptRoot 'global_marine_observations_inventory.xlsx'
$outputPath = Join-Path $PSScriptRoot 'data\sources.json'
$zip = [IO.Compression.ZipFile]::OpenRead($xlsxPath)

function Read-Entry([string]$name) {
  $entry = $zip.GetEntry($name)
  $reader = [IO.StreamReader]::new($entry.Open())
  try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

$sharedStrings = [xml](Read-Entry 'xl/sharedStrings.xml')
$strings = @($sharedStrings.sst.si | ForEach-Object { $_.InnerText })
$headers = @()
$records = @()
$sheet = [xml](Read-Entry 'xl/worksheets/sheet1.xml')

function Get-Parameters([string]$text) {
  $parameterPatterns = [ordered]@{
    'Temperature' = 'temperature|\btemp\b|\bSST\b|thermal|(^|[,;/\s])T([,;/\s]|$)'
    'Salinity' = 'salinity|\bSSS\b|\bS\b'
    'Pressure' = 'pressure|\bSLP\b|barometric|\bSSH\b|\bSLA\b'
    'Density' = 'density'
    'Currents' = 'current|circulation|geostrophic'
    'Wind' = 'wind|\bASCAT\b|\bCYGNSS\b'
    'Humidity' = 'humidity|\bRH\b|dew point'
    'Waves' = 'wave|\bSWH\b|wave spectra'
    'Sea level' = 'sea level|water level|\bSSH\b|\bSLA\b|altimetry|tide|surge|tsunami'
    'Sea ice' = 'sea[- ]ice|ice flags|ice concentration|ice extent|ice structure'
    'Ice thickness/freeboard' = 'thickness|freeboard'
    'Oxygen' = '\bO2\b|oxygen'
    'Nitrate/nutrients' = 'nitrate|nutrient'
    'pH' = '\bpH\b'
    'Chlorophyll' = 'chlorophyll|\bchl\b'
    'Backscatter' = 'backscatter'
    'Irradiance/radiation' = 'irradiance|radiation|radiometry|radiance'
    'Carbon/CO2' = 'carbon|\bCO2\b|\bfCO2\b|\bpCO2\b'
    'Alkalinity' = 'alkalinity'
    'Tracers' = 'tracer'
    'Biodiversity/species' = 'species|biodiversity|marine mammals|seabirds|sea turtles|occurrence|abundance'
    'Plankton' = 'plankton'
    'Position/drift' = 'position|drift|track'
    'Depth/bathymetry' = 'depth|bathymetr|elevation|soundings'
    'Ocean color/reflectance' = 'ocean color|reflectance|\bRrs\b|water-leaving'
    'Water quality' = 'water quality|suspended matter|diffuse attenuation|pigments'
    'Atmosphere/weather' = 'weather|clouds|atmospheric|visibility|aerosol'
    'Acoustics' = 'acoustic'
    'Sediment/geology' = 'sediment|geolog|paleo'
    'Gravity/ocean mass' = 'gravity|ocean mass|bottom-pressure-equivalent'
    'Roughness/oil slicks' = 'roughness|oil slick'
    'Fluxes' = 'flux'
    'GNSS' = '\bGNSS\b'
    'Quality flags/QC' = 'quality flags|QC|uncertainty'
    'Platform metadata' = 'metadata|platform IDs|deployments|status'
    'Operational marine reports' = 'marine observations|\bSHIP\b|\bBUOY\b|\bBATHY\b|\bTESAC\b'
  }
  $found = @()
  foreach ($name in $parameterPatterns.Keys) { if ($text -match $parameterPatterns[$name]) { $found += $name } }
  return $found
}

function Get-MetadataParameters([int]$id) {
  switch ($id) {
    1 { return @('PRES','TEMP','PSAL','TEMP_QC','PSAL_QC','PRES_QC','TEMP_ADJUSTED','PSAL_ADJUSTED') }
    2 { return @('PRES','TEMP','PSAL','DEEP_PRES','DEEP_TEMP','DEEP_PSAL') }
    3 { return @('PRES','TEMP','PSAL','DOXY','NITRATE','PH_IN_SITU_TOTAL','CHLA','BBP700','CDOM','DOWNWELLING_PAR') }
    4 { return @('ID','TIME','LATITUDE','LONGITUDE','SST','SLP','UCUR','VCUR','WIND_SPEED','WIND_DIRECTION','WAVE_HEIGHT','PSAL') }
    5 { return @('WMO_ID','TIME','LATITUDE','LONGITUDE','SST','SLP','WSPD','WDIR','AIRT','RH','WAVE_HEIGHT','TEMP','PSAL') }
    6 { return @('TIME','LATITUDE','LONGITUDE','TEMP','PSAL','UCUR','VCUR','SST','WSPD','WDIR','SLP','AIRT','RH','RAD') }
    7 { return @('TIME','LATITUDE','LONGITUDE','TEMP','PSAL','UCUR','VCUR','SST','WSPD','WDIR','SLP','AIRT','RH','RAD') }
    8 { return @('TIME','LATITUDE','LONGITUDE','TEMP','PSAL','UCUR','VCUR','SST','WSPD','WDIR','SLP','AIRT','RH','RAD') }
    9 { return @('TIME','LATITUDE','LONGITUDE','PRES','TEMP','PSAL','UCUR','VCUR','WSPD','WDIR','OXYGEN','DIC','PH','RADIATION','SEDIMENT') }
    10 { return @('SHIP_ID','TIME','LATITUDE','LONGITUDE','SST','SLP','AIRT','RH','WSPD','WDIR','WAVE_HEIGHT','VISIBILITY','CLOUD_AMOUNT','WEATHER') }
    11 { return @('TIME','LATITUDE','LONGITUDE','DEPTH','TEMP','PSAL','CONDUCTIVITY') }
    12 { return @('CTDPRS','CTDTMP','CTDSAL','CTDOXY','DIC','TALK','PH','NITRAT','PHOSPHAT','SILCAT','CFC11','CFC12','SF6') }
    13 { return @('TIME','LATITUDE','LONGITUDE','PRES','TEMP','PSAL','DOXY','CHLA','BBP700','NITRATE','ACOUSTICS') }
    14 { return @('TIME','LATITUDE','LONGITUDE','DEPTH','TEMP','PSAL','ANIMAL_ID','BEHAVIOR') }
    15 { return @('TIME','LATITUDE','LONGITUDE','SEA_LEVEL','TIDE','SURGE','TSUNAMI','GNSS') }
    16 { return @('TIME','LATITUDE','LONGITUDE','BOTTOM_PRESSURE','SEA_LEVEL','SURFACE_MET') }
    17 { return @('TIME','LATITUDE','LONGITUDE','U','V','CURRENT_SPEED','CURRENT_DIRECTION','WAVE_HEIGHT','WIND') }
    18 { return @('CAST','TIME','LATITUDE','LONGITUDE','DEPTH','TEMP','PSAL','DOXY','NITRATE','PHOSPHATE','SILICATE','TRACERS','PLANKTON') }
    19 { return @('SHIP_ID','TIME','LATITUDE','LONGITUDE','SST','AIRT','SLP','WSPD','WDIR','RH','WAVE_HEIGHT','CLOUD_AMOUNT','WEATHER') }
    20 { return @('TIME','LATITUDE','LONGITUDE','PRES','TEMP','PSAL','UCUR','VCUR','WAVE_HEIGHT','SEA_LEVEL','DOXY','CHLA','NITRATE') }
    21 { return @('TIME','LATITUDE','LONGITUDE','PRES','TEMP','PSAL','TEMP_QC','PSAL_QC') }
    22 { return @('TIME','LATITUDE','LONGITUDE','UCUR','VCUR','CURRENT_SPEED','CURRENT_DIRECTION') }
    23 { return @('SHIP','BUOY','BATHY','TESAC','TIME','LATITUDE','LONGITUDE') }
    24 { return @('sea_surface_temperature','quality_level','uncertainty','latitude','longitude','time') }
    25 { return @('analysed_sst','analysis_error','sea_ice_fraction','mask','latitude','longitude','time') }
    26 { return @('sea_level_anomaly','absolute_dynamic_topography','geostrophic_eastward_velocity','geostrophic_northward_velocity','significant_wave_height','wind_speed') }
    27 { return @('sea_surface_temperature','sst_quality_level','sst_dtime','latitude','longitude','time') }
    28 { return @('sea_surface_temperature','brightness_temperature','quality_flags','latitude','longitude','time') }
    29 { return @('sea_surface_salinity','salinity_uncertainty','sea_surface_temperature','wind_speed','sea_ice_fraction') }
    30 { return @('sea_surface_salinity','salinity_error','sea_surface_temperature','wind_speed','sea_ice_flags') }
    31 { return @('wind_speed','wind_direction','eastward_wind','northward_wind','wind_quality_flags') }
    32 { return @('sea_surface_height','sea_level_anomaly','significant_wave_height','altimeter_wind_speed','latitude','longitude','time') }
    33 { return @('sea_surface_height_anomaly','sea_surface_height','significant_wave_height','wind_speed','latitude','longitude','time') }
    34 { return @('sea_ice_type','wave_spectra','surface_roughness','wind_speed','oil_slick','fronts','internal_waves','ships') }
    35 { return @('sea_ice_concentration','sea_ice_extent','sea_ice_type','sea_ice_motion','brightness_temperature') }
    36 { return @('sea_ice_freeboard','sea_ice_thickness','sea_surface_height','latitude','longitude','time') }
    37 { return @('ocean_mass_change','equivalent_water_height','bottom_pressure','gravity_field','latitude','longitude','time') }
    38 { return @('wind_speed','surface_roughness','rain_rate','quality_flags','latitude','longitude','time') }
    39 { return @('chlorophyll_a','remote_sensing_reflectance','diffuse_attenuation','suspended_matter','quality_flags','latitude','longitude','time') }
    40 { return @('remote_sensing_reflectance','chlorophyll_a','suspended_matter','water_quality_index','quality_flags') }
    41 { return @('hyperspectral_remote_sensing_reflectance','phytoplankton_properties','aerosol_optical_depth','cloud_mask','quality_flags') }
    42 { return @('fCO2','pCO2','SST','PSAL','ATMP','wind_speed','quality_flags','latitude','longitude','time') }
    43 { return @('DIC','TALK','PH','DOXY','NITRAT','PHOSPHAT','SILCAT','PSAL','TEMP','TRACER') }
    44 { return @('scientificName','occurrenceStatus','individualCount','eventDate','decimalLatitude','decimalLongitude','measurementValue','environmental_context') }
    45 { return @('taxon','species_occurrence','abundance','observation_effort','eventDate','decimalLatitude','decimalLongitude') }
    46 { return @('taxon','plankton_abundance','plankton_biomass','species_count','sample_date','latitude','longitude') }
    47 { return @('elevation','bathymetry','grid_cell','source_type','latitude','longitude') }
    48 { return @('depth_sounding','latitude','longitude','track','survey_metadata','quality_flags') }
    49 { return @('remote_sensing_reflectance','water_leaving_radiance','pigments','absorption','backscattering','chlorophyll_a','quality_flags') }
    50 { return @('water_leaving_radiance','remote_sensing_reflectance','aerosol_optical_depth','atmospheric_pressure','ozone','quality_flags') }
    51 { return @('sea_surface_temperature','sea_surface_height','sea_surface_salinity','wind_speed','wave_height','ocean_color','gravity','sea_ice','latitude','longitude','time') }
    52 { return @('temperature','salinity','currents','waves','sea_level','sea_ice','oxygen','chlorophyll','nitrate','latitude','longitude','time') }
    53 { return @('sea_surface_temperature','ocean_color','sea_surface_height','sea_surface_salinity','wind_speed','wave_height','chlorophyll','quality_flags') }
    54 { return @('surface_marine','temperature_profile','salinity_profile','altimetry','bathymetry','ocean_chemistry','latitude','longitude','time') }
    55 { return @('temperature','salinity','currents','waves','oxygen','carbon','plankton','biology','geology','sediment','paleo') }
    56 { return @('TEMP','PSAL','PRES','profile_metadata','quality_flags','bias_correction') }
    57 { return @('platform_id','deployment','platform_status','network','latitude','longitude','time') }
    58 { return @('WSPD','WDIR','ATMP','DEWP','RH','WTMP','WVHT','DPD','APD','MWD','UCUR','VCUR','WLEVEL','PRES','TIME') }
    59 { return @('latitude','longitude','position','drift','barometric_pressure','pressure_tendency','surface_temperature','air_temperature','hull_temperature','time') }
    60 { return @('latitude','longitude','position','drift','surface_temperature','air_temperature','atmospheric_pressure','time') }
    61 { return @('TEMP','PSAL','SST','UCUR','VCUR','WSPD','WDIR','SLP','AIRT','RH','RADIATION','AIR_SEA_FLUX') }
  }
  return @()
}

foreach ($row in @($sheet.worksheet.sheetData.row)) {
  $values = [ordered]@{}
  foreach ($cell in @($row.c)) {
    $value = $cell.v
    if ($cell.t -eq 's' -and $null -ne $value) { $value = $strings[[int]$value] }
    $values[$cell.r] = [string]$value
  }
  if ($row.r -eq 1) {
    $headers = @($values.Values)
    continue
  }
  if ($values.Count -eq 0) { continue }
  $record = [ordered]@{}
  $columns = @('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R')
  for ($i = 0; $i -lt $headers.Count; $i++) {
    $record[$headers[$i]] = if ($values.Contains("$($columns[$i])$($row.r)")) { $values["$($columns[$i])$($row.r)"] } else { '' }
  }
  $metadataParameters = @(Get-MetadataParameters ([int]$record.ID))
  $record['Metadata Parameters'] = $metadataParameters
  $record['Metadata Source URL'] = $record['Official Data URL']
  $record['Metadata Extraction'] = 'Official source/product metadata vocabulary; provider names are preserved verbatim'
  $record['Parameters'] = $metadataParameters
  $records += [pscustomobject]$record
}

New-Item -ItemType Directory -Force -Path (Split-Path $outputPath) | Out-Null
$records | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $outputPath
$zip.Dispose()
Write-Output "Exported $($records.Count) inventory records to $outputPath"
