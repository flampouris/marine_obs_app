# Marine Observation Discovery

This app uses only two versioned v3 runtime inputs: `global_marine_observation_source_registry_v3.json` and `marine_parameter_dictionary_v3.json`. It is a metadata-first discovery tool for investigating which registered sources may contain an observation by:

- Canonical parameter family and canonical parameter
- Source or network
- Platform or sensor
- Latitude, longitude, and radius
- Time window
- Depth range
- QC or data mode

The registry describes source capabilities and query dimensions. It does not itself contain the raw observations. Results are candidate sources; provider connectors must be added to confirm exact records.

## Versioned inputs

The page loads the v3 source registry and v3 canonical dictionary directly. The registry embeds the coverage mappings and download-target catalog, so the browser does not load the older standalone v2 coverage file or the unversioned download-ID file. Together, the two v3 inputs contain 42 sources, 96 canonical parameters, 368 parameter mappings, 259 parameter-specific download targets, provider dataset IDs, URL templates, variable selectors, access protocols, authentication requirements, and download-readiness statuses. This includes mappings such as Conservative Temperature where the native metadata or CF standard name supports it.

The coverage index supplies numeric latitude/longitude bounds, start/end dates, depth bounds, vertical reference, coverage status, and precision readiness. The UI uses range overlap for location, time, and depth filters. Rows marked `coarse_envelope`, `dynamic_required`, or `review_required` are routing-level coverage and should not be interpreted as exact observation existence until the specified connector harvest is run.

## Run the app

Start the local server:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\serve.ps1
```

Then open:

```text
http://localhost:8765/
```

Reference pages:

- `http://localhost:8765/help.html` — walkthrough
- `http://localhost:8765/source-catalog.html` — source synopsis
- `http://localhost:8765/canonical-dictionary.html` — canonical parameters and source-native names

Keep the server terminal open. The app loads the versioned JSON inputs through the local server; opening `index.html` directly may prevent the JSON from loading.

## Source details

Select **Inspect source** on any result to see its variables, spatial/time/depth metadata, QC/data mode, native query filters, integration notes, download recipe, official access/documentation links, and provider-specific Python and Bash examples for downloading one dataset or subset. Examples include placeholders when a provider requires selecting a dataset or granule from its catalog first.

Run the download-target audit with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-download-examples.ps1
```

This lists the preferred parameter-specific provider ID, variable selector, URL strategy, and readiness status for every source. The catalog currently contains 259 targets across all 42 sources. `ready_static_id` targets can use the displayed URL directly; `ready_dynamic_key` targets include placeholders such as station, deployment, or index keys; `search_required`, `mapping_review_required`, `review_filetype_required`, and `metadata_only` targets still require provider-specific resolution before a download can be tested. `-ProbeCatalogUrls` checks provider catalog reachability only.

## Next implementation layer

The registry recommends separating:

1. Source capabilities
2. Dataset/file/granule catalog
3. Observation index
4. Optional raw/object storage

The current app implements the first layer and uses it to produce discovery candidates. The next step is adding source connectors that populate dataset and observation indexes for priority sources such as Argo, NDBC, GDP, WOD, and other networks.

## Validate parameter filtering

Run the full canonical-parameter coverage check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\validate-parameter-filter.ps1
```

Validate that `index.html` still provides every element required by `app.js`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-ui-contract.ps1
```

The GitHub Pages workflow runs this check before uploading the website. It verifies every literal `$('element-id')` reference in `app.js`, rejects undeclared or missing IDs, and rejects duplicate IDs in `index.html`.

Generate the crawlable SEO pages, sitemap, and robots file with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate-seo-pages.ps1
```

This creates one static page for each of the 42 sources and pages for the 40 canonical parameters mapped by the largest number of distinct sources. The Pages workflow regenerates them before every deployment.

Validate the generated canonical URLs, sitemap, UTF-8 content, and JSON-LD with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-seo-pages.ps1
```
