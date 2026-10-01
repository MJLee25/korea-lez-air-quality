# Data access and input requirements

## Public and non-public material

This release follows the author's instruction not to redistribute original AirKorea data. It also excludes prepared district-month panels and station extracts rather than treating aggregation alone as permission to redistribute observations. This document does not make a new legal determination about provider licenses.

Public: model coefficients and impacts; inference summaries; group-time/event-month estimated contrasts; cross-season tests; validation/error/count summaries; district rollout membership and derived district centroid coordinates; aggregate monthly scores and observed information matrices. Scores are summed across districts within a model/month and are not per-observation fitted objects. Map images are retained article assets; source boundary files are not included.

Excluded: hourly archives, daily weather records, station-month concentrations, `02_final_data.csv`, `nearest_panel.csv`, `interpolation_station_input.csv`, geographic source files, source spreadsheets, raw RDS files, prepared-data ZIPs, and observation-bearing model/event caches. `.gitignore` is a convenience; `python scripts/verify_release.py` checks the distribution itself.

## Prepared-data model refitting

Obtain inputs lawfully or use the separate review-data package supplied by the corresponding author for authorized review. That package is **not downloaded by these scripts**. Put these three files in a directory outside the public repository:

| File | Requirement |
|---|---|
| `02_final_data.csv` | Corrected IDW panel, release `20260920-re`; 38,844 rows and 36 fields before island exclusion |
| `nearest_panel.csv` | Same district-month keys and annual covariates; common-grid nearest-station pollution and weather fields |
| `analysis_coordinates.csv` | Analysis district centroids (`id,x,y,epsg`); 247 rows, EPSG:5179; same policy-neighbor geometry |

The analysis excludes Ongjin-gun and Ulleung-gun, retaining 247 districts × 156 months = 38,532 observations in 2012–2024. The first six panel columns are district ID, year, month, province, district, and large district. Exact column schema: [input_schema.json](input_schema.json). Gases are already ppb: do not multiply by 1,000 again. District membership, cohort counts (174/25/35/13), unique keys and panel completeness are checked by the estimation code.

The public runner copies these private inputs only into the explicitly selected model-output directory. Keep that output outside this repository. Prepared inputs are hashed in the original provenance records for comparison; a schema match alone does not establish that data match the manuscript.

## Source preprocessing replay

The corrected preprocessing starts from supplied reconstruction inputs, not a fresh download of all original hourly archives. In the external source package, keep a unique `04_*` evidence directory with a child directory containing:

- `air_raw_month_with_metadata.csv.gz`: monthly source pollution summaries, coverage and duplicate/metadata audit fields.
- `kma_raw_selected.csv.gz`, `kma_coordinate_history.csv`: selected daily weather observations and dated coordinate history.
- `rain_official_comparison.csv`: archived precipitation totals/checks.
- `coordinate_5179_lookup.csv`: coordinate transformation lookup.
- `grid_points.csv`, `grid_area_weights.csv`: common land grid and district intersection weights.
- `annual_covariates.csv`: reconciled annual covariates.

`reproduce_validation.py` additionally needs `02_final_data.csv` in the source package, `cv_summary.csv`, `interpolation_support.csv`, and the archived precipitation HTML ZIP in the `04_*` evidence directory. `build_nearest_panel.py` needs the replayed `interpolation_station_input.csv` and the same grid/weights. These inputs are not included in the public release.

Run the bundled `source_preprocessing/replay_supplied.R` wrapper rather than the legacy `00_전체실행.R` launcher, whose original local path is preserved for provenance. The wrapper reads external inputs and executes the bundled corrected scripts into an explicitly separate destination. Set `LEZ_SOURCE_DIR`, `LEZ_STATION_INPUT`, and `LEZ_VALIDATION_OUTPUT` as described in the reproduction guide.

Original source locations and qualifications are retained in `paper/OnlineResource1.tex`, Section S6, and `OnlineResource2/provenance/POLICY_EVIDENCE.md`. Obtain source records directly from AirKorea, KMA, and KOSIS under their applicable terms. A review-data permission does not itself authorize a public upload.
