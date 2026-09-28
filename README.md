# Marine Observation Discovery

Marine Observation Discovery is a metadata-first web application for finding global marine-observation sources that may satisfy a scientific query. It searches source capabilities and indexed coverage; it does not claim that an individual observation exists until the provider is queried.

Live website: <https://www.flampouris.com/marine_obs_app/>

## Current application

The interface can filter candidate sources by:

- Canonical parameter family and parameter
- Source or network
- Platform or sensor
- Latitude, longitude, and radius
- Start and end date
- Minimum and maximum depth
- QC or data mode

The website also provides:

- A walkthrough page
- A catalog of all 42 registered sources
- A dictionary of 96 canonical parameters and their source-native aliases
- Source inspection dialogs with provider access links and Python/Bash download examples
- Static, crawlable pages for all sources and the 40 most widely mapped parameters
- Canonical metadata, an XML sitemap, and Schema.org structured data

The map was intentionally removed from the current interface.

## V3 runtime inputs

The browser loads only these two JSON files:

- `global_marine_observation_source_registry_v3.json`
- `marine_parameter_dictionary_v3.json`

The v3 registry currently contains:

- 42 sources
- 368 source-to-parameter mappings
- 259 parameter-specific download targets
- Spatial, temporal, and depth coverage metadata
- Provider dataset identifiers, URL templates, protocols, authentication requirements, and readiness statuses

The v3 dictionary contains 96 canonical parameters, including definitions, units, CF names or controlled vocabularies, UI families, qualifiers, merge policies, and source-native aliases.

The following files remain in the repository for archival or future development but are not loaded by the website:

- `marine_parameter_download_ids.json`: its download targets are embedded in the v3 registry.
- `marine_parameter_coverage_v2.json`: its mappings are embedded in the v3 registry.
- `marine_parameter_dictionary_v2.json`: superseded by the v3 dictionary.
- `world.geo.json`: previously used by the map, which has been removed.

## Run locally

From PowerShell in the repository directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\serve.ps1
```

Open <http://localhost:8765/> and keep the server terminal running.

Reference pages:

- <http://localhost:8765/help.html> — walkthrough
- <http://localhost:8765/source-catalog.html> — source catalog
- <http://localhost:8765/canonical-dictionary.html> — canonical dictionary

Do not open `index.html` directly from the filesystem. The app must run through an HTTP server so the browser can fetch its JSON inputs.

## Update the data

Use the v3 files as the authoritative website inputs:

1. Update `global_marine_observation_source_registry_v3.json` for sources, coverage mappings, and download targets.
2. Update `marine_parameter_dictionary_v3.json` for canonical parameters and aliases.
3. Preserve canonical keys and source IDs because the UI and generated URLs depend on them.
4. Run the validation and generation commands below.
5. Review the app locally before committing.

The coverage filters use range overlap. Coarse, dynamic, or review-required coverage is suitable for routing users to candidate providers but is not proof that a matching observation exists.

## Validate before deployment

Run these commands from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-ui-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-v3-inputs.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate-seo-pages.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-seo-pages.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-download-examples.ps1
```

These checks verify that:

- `app.js` references valid HTML elements.
- The website and build scripts use only the v3 runtime inputs.
- The expected sources, parameters, mappings, and download targets are present.
- Static source and parameter pages can be generated.
- Canonical URLs, JSON-LD, UTF-8 content, and sitemap entries are valid.
- Every source has an indexed download-target strategy.

To probe provider catalog URLs as well, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test-download-examples.ps1 -ProbeCatalogUrls
```

Provider probes test endpoint reachability; they do not prove that every example downloads an observation successfully.

## SEO generation

Generate the crawlable source pages, parameter pages, `sitemap.xml`, and the app-level `robots.txt` with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate-seo-pages.ps1
```

The deployment workflow runs this generator automatically. The root-domain crawler file is maintained in the separate `flampouris/flampouris.github.io` repository and advertises:

```text
https://www.flampouris.com/marine_obs_app/sitemap.xml
```

## Deploy the website manually

The production website is deployed from the `main` branch by `.github/workflows/pages.yml`. No `gh` command is required.

### Method 1: push an update

Run the validations above, then commit and push:

```powershell
git status
git add --all
git commit -m "Describe the website update"
git pull --rebase origin main
git push origin main
```

Pushing to `main` starts the **Verify and deploy GitHub Pages** workflow automatically. The workflow validates the UI and v3 inputs, regenerates the SEO pages, validates the generated files, and deploys the site.

To monitor it without GitHub CLI:

1. Open <https://github.com/flampouris/marine_obs_app/actions>.
2. Select **Verify and deploy GitHub Pages**.
3. Open the newest run and wait for both `build` and `deploy` to become green.
4. Open <https://www.flampouris.com/marine_obs_app/>.
5. If the browser shows an older version, perform a hard refresh with `Ctrl+F5`.

### Method 2: redeploy the current commit from GitHub

Use this when the correct files are already on `main` but the website needs to be deployed again:

1. Open <https://github.com/flampouris/marine_obs_app/actions/workflows/pages.yml>.
2. Select **Run workflow**.
3. Choose the `main` branch.
4. Select **Run workflow** again.
5. Wait for the build and deployment jobs to complete.

### Verify the public deployment

Check these URLs after the workflow succeeds:

- <https://www.flampouris.com/marine_obs_app/>
- <https://www.flampouris.com/marine_obs_app/global_marine_observation_source_registry_v3.json>
- <https://www.flampouris.com/marine_obs_app/marine_parameter_dictionary_v3.json>
- <https://www.flampouris.com/marine_obs_app/sitemap.xml>
- <https://www.flampouris.com/robots.txt>

The page header should report `42 sources · v3 catalog ready` after the two JSON inputs load.

## Git ownership warning

If Git reports `detected dubious ownership`, trust this specific repository for the current Windows user:

```powershell
git config --global --add safe.directory "D:/Source Code/marine_obs_app"
```

Run that command only for the repository path you recognize and control.

## Architecture boundary

The current app is a discovery layer. A complete observation service would separate:

1. Source capabilities
2. Dataset, file, and granule catalogs
3. Observation-level indexes
4. Optional raw or object storage

Provider connectors are still required to confirm exact records and retrieve raw observations from networks such as Argo, NDBC, GDP, WOD, Copernicus Marine, PANGAEA, and NASA archives.
