# Analysis code and results for the study

## Monitoring-based assessment of spatial and seasonal air-quality associations with low-emission zones in South Korea

This repository contains the R and Python code, aggregate results, and reproducibility resources accompanying the manuscript by **Minju Lee and Mijeong Kim**. The study examines pollutant-specific spatial and seasonal air-quality associations with South Korea's phased permanent Low Emission Zone (LEZ) expansion using a monthly panel of **247 si-gun-gu units during 2012–2024**.

The analysis combines group-time event-study diagnostics for staggered designation, non-spatial two-way fixed-effects (TWFE) benchmarks, and spatial Durbin models (SDMs). It includes score-based heteroskedasticity and autocorrelation consistent (HAC) inference, seasonal comparisons, interpolation-sensitivity analyses, alternative policy-date assignments, and numerical verification.

**The [OnlineResource2](OnlineResource2/README.md) directory is Online Resource 2 cited in the manuscript and Online Resource 1.** It supplies the analysis and corrected preprocessing scripts, aggregate results, provenance records, and input requirements. The [manuscript-to-results index](docs/RESULTS_INDEX.md) links every main and supplementary table and figure to its result files and generating code.

## Data sources and construction

### Air pollution

- **Sources:** [AirKorea final-confirmed hourly archive](https://www.airkorea.or.kr/web/last_amb_hour_data?pMENU_NO=123) and the [AirKorea station-information API](https://www.data.go.kr/data/15073877/openapi.do).
- **Outcomes:** Monthly urban ambient concentrations of NO₂, CO, SO₂, O₃, and PM₁₀. Gases are expressed in ppb and PM₁₀ in µg/m³. Roadside series are retained in the preprocessing workflow but are not the regression outcomes.
- **Screening:** The corrected workflow distinguishes invalid negative codes, missing observations, and numeric zero; excludes station–month–pollutant groups with duplicate timestamps; and requires at least 75% valid calendar hours in retained groups. Station matching and coordinate qualifications are documented in Online Resource 1, Section S6.
- **Spatial construction:** Eligible monthly station values are interpolated with IDW, power 2, in projected EPSG:5179 coordinates. Predictions at common grid-cell centers are aggregated to districts using district–cell intersection-area weights. The nearest-station sensitivity analysis uses the same grid, weights, and eligible station support.

### Meteorology

- **Sources:** [KMA ASOS daily-observation API](https://www.data.go.kr/data/15059093/openapi.do) and the [KMA Open MET Data Portal](https://data.kma.go.kr/resources/html/en/ncdci.html).
- **Monthly variables:** Mean daily temperature (`avg_temp`), mean daily sunshine duration (`sun_time`, h/day), low-wind equivalent days (`stagnant_days`), mean wind speed (`avg_wind`), mean relative humidity (`avg_humid`), and mean daily precipitation (`avg_rain`, mm/day).
- **Construction:** Daily observations are matched to dated station coordinates before monthly summarization. Non-precipitation variables require at least 75% valid calendar days. For low-wind equivalent days, the monthly count of valid days with mean wind speed ≤ 2 m/s is divided by the number of valid wind days and multiplied by the number of calendar days in that month. This is a coverage-adjusted low-wind measure, not a full atmospheric-stagnation index.
- **Precipitation:** Retained monthly totals are reconciled against archived KMA station-year precipitation tables and divided by the actual number of calendar days in the month. Unexplained missing daily values are not automatically converted to zero.
- **Spatial construction:** The six weather fields use the same IDW-to-grid and district-area aggregation framework. The nearest-station comparison changes both pollution and weather fields jointly.

### Urban structure

- **Source:** [KOSIS/LX urban-area statistics](https://kosis.kr/statHtml/statHtml.do?orgId=101&tblId=DT_1YL20421E&conn_path=I3), together with the population and fixed-boundary inputs documented in the source audit.
- **Variables:** Population density (`pop_density`), industrial area per capita (`industrial_area`), commercial area per capita (`commercial_area`), and green area per capita (`green_area_per_capita`). Area-per-capita measures are expressed in m²/person.
- **Construction:** Population density uses population divided by fixed-boundary district land area. Annual covariates are repeated across months within each district-year. Continuous controls are standardized within each fitted specification before constructing their spatial lags.

### Transportation

- **Sources:** [KOSIS motor vehicle registrations per capita](https://kosis.kr/statHtml/statHtml.do?orgId=101&tblId=DT_1YL20731&conn_path=I3) and [Korea Transportation Safety Authority vehicle-distance statistics](https://kosis.kr/statHtml/statHtml.do?orgId=426&tblId=DT_426001_N004&conn_path=I3).
- **Variables:** Registered cars per capita (`cars_per_capita`) and average daily distance per vehicle (`daily_km`, km/vehicle/day).
- **Construction:** Cars per capita is registered vehicles divided by population. Annual values repeat across months. The disclosed Sejong 2012 vehicle-distance imputation uses its 2013–2024 annual mean; the 2013-start and transport-omission specifications provide relevant sensitivity checks.
- **Model scope:** Road paving rate is excluded from the current analysis.

The monthly analysis code creates the following policy variables:

| Variable | Definition |
|---|---|
| `time` | Calendar-month index, with January 2012 = 1 and December 2024 = 156. |
| `g` | First assigned designation month: 61, 79, or 97 under baseline timing; 0 for never-designated units. Timing-sensitivity specifications recode the relevant month. |
| `cohort` | Original geographic cohort membership, retained when alternative months are assigned. |
| `lez` | Time-varying indicator equal to 1 from the assigned designation month onward and 0 otherwise. |
| `w_lez` | Spatial lag of `lez`, constructed using the fitted specification's spatial-weight matrix. |
| `season` | Winter: December–February; Spring: March–May; Summer: June–August; Autumn: September–November. Individual months remain the observations. |

The primary spatial-weight matrix is row-standardized and connects each district to its five nearest district centroids. Alternative specifications use three or seven neighbors. These policy-neighbor weights are distinct from the interpolation weights used to construct environmental fields.

## Analysis sample and required inputs

The primary balanced sample comprises **247 districts × 156 months = 38,532 district-month observations**, excluding Ongjin-gun and Ulleung-gun from the supplied 249-unit panel. The 2013–2024 comparison contains 35,568 observations. Each seasonal model uses 247 districts and 39 observed months.

**Regenerating tables and statistical figures from the included aggregate results does not require observation-level data.** Refitting the models requires the following separate prepared inputs:

| File | Contents |
|---|---|
| `02_final_data.csv` | Corrected IDW panel, release `20260920-re`: 38,844 rows and 36 columns before the island exclusions. |
| `nearest_panel.csv` | Common-support nearest-station panel with matching district-month keys and annual covariates. |
| `analysis_coordinates.csv` | Derived analysis-district centroids, with fields `id`, `x`, `y`, and `epsg`; 247 districts in EPSG:5179. |

District identifiers must match across the prepared panels and coordinate file. Preserve the supplied identifiers and first six panel columns rather than assigning new IDs independently. The complete column schema and reference input hashes are provided in [input_schema.json](docs/input_schema.json). Prepared gas concentrations are already in ppb and must not be multiplied by 1,000 again.

Original hourly and daily observations, station-level extracts, prepared observation-level panels, source boundary files, and the separate review-data package are **not included**. The public files contain aggregate estimates, statistical tests, audit summaries, district policy metadata, and monthly aggregate score/information caches. Authorized model refitting requires the separate review-data package or equivalent lawfully obtained prepared inputs. Obtaining source records alone does not replace the documented reconstruction steps. See [data access and input requirements](docs/DATA_ACCESS.md).

## Repository structure

```text
├── OnlineResource2/                    # Online Resource 2 cited in the paper
│   ├── analysis/                       # Estimation, inference, tables and checks
│   │   ├── monthly_analysis_journal.R
│   │   ├── monthly_inference_journal.R
│   │   ├── monthly_outputs_journal.R
│   │   ├── seasonal_comparisons_journal.R
│   │   ├── journal_outputs.R
│   │   ├── timing_outputs.py
│   │   ├── validation_outputs.py
│   │   ├── verify_public.R
│   │   ├── verify_monthly.R
│   │   ├── check_event_warnings.R
│   │   ├── build_nearest_panel.py
│   │   └── reproduce_validation.py
│   ├── source_preprocessing/           # Corrected preprocessing and replay wrapper
│   ├── monthly_results/                # Aggregate CSVs, reports and score caches
│   ├── tables/                         # 13 generated numerical table fragments
│   ├── validation_evidence/            # Archived source-audit summaries
│   ├── provenance/                     # Input hashes and script provenance
│   └── README.md
├── results/                            # All main and supplementary result assets
│   ├── figures/
│   ├── tables/
│   ├── previews/
│   └── README.md
├── paper/                              # Manuscript and Online Resource 1 LaTeX sources
├── docs/                               # Result index, data requirements and verification
├── scripts/                            # Setup, isolated execution and release checks
├── requirements.txt
├── manifest_sha256.csv
├── CITATION.cff
└── README.md
```

This structure corresponds to the `_260930` package. The separate numbered, English-commented `_260930-my` edition is not required to use this repository.

## Software requirements

- **R:** The original full-analysis run used R 4.6.1. Public-output reproduction and a baseline NO₂ refit were also checked with Windows R 4.6.0. Cairo support is required for embedded-font PDF figures.
- **Public-output R packages:** `dplyr`, `ggplot2`, `sf`, and `spdep`.
- **Additional model-refitting packages:** `readxl`, `tidyr`, `splm`, `plm`, `did`, `geojsonsf`, and `numDeriv`.
- **Python:** Python 3.10 or later, with `numpy` and `pandas`; source-audit reproduction additionally uses `lxml`.

The original R environment and package versions are recorded in [sessionInfo.txt](OnlineResource2/monthly_results/sessionInfo.txt). The [tested-environment notes](docs/TESTED_ENVIRONMENT.md) distinguish that environment from the public-package checks. The installer obtains available packages and is not a frozen historical environment; exact bootstrap comparisons require attention to the recorded package versions, including `did`.

## How to run

### 1. Reproduce public tables, statistical figures and aggregate checks

Run from the repository root:

```sh
python -m pip install -r requirements.txt
Rscript scripts/install_dependencies.R public
python scripts/verify_release.py
python scripts/reproduce.py public
```

The runner creates a new `generated/public/OnlineResource2/` working directory and leaves the archived results unchanged. Use `--output /path/to/new-run` to select another destination. Existing output directories are refused to prevent mixing runs. If Rscript is not on PATH, add `--rscript "C:/Program Files/R/R-4.6.0/bin/Rscript.exe"` to the reproduction command.

After checking the aggregate-cache schemas and signatures, the runner executes:

| Order | Script | Output |
|---|---|---|
| 1 | `monthly_outputs_journal.R` | Ten numerical table fragments, Figure 2, Figure S1, and a baseline seasonal plot. |
| 2 | `seasonal_comparisons_journal.R` | Seasonal omnibus and pairwise comparisons, pooled multiplicity results, and Table S7. |
| 3 | `journal_outputs.R` | Main Figure 3, comparing baseline and cohort-trend seasonal totals. |
| 4 | `timing_outputs.py` | Timing-sensitivity results and Table S12. |
| 5 | `validation_outputs.py` | Table S9 from the archived station-validation summaries. |
| 6 | `verify_public.R` | Aggregate consistency checks and explicit spatial-matrix decompositions. |

These steps regenerate **13 numerical tables and the statistical figures** from included aggregate outputs. They do not refit the observation-level models. Main Table 2, Tables S8 and S11, and Figure 1 are preserved definition/evidence/geography assets. The original map-building code and source boundary inputs were not supplied in Online Resource 2, so regenerating Figure 1 from boundaries is not claimed.

### 2. Refit models using separate prepared inputs

Place the three required prepared files in a private directory outside this repository, then run:

```sh
Rscript scripts/install_dependencies.R models
python scripts/reproduce.py probe --data-dir /private/prepared-inputs --output /private/lez-probe
python scripts/reproduce.py models --data-dir /private/prepared-inputs --output /private/lez-full-run
```

The `probe` mode audits the inputs and refits baseline NO₂. The `models` mode runs all SDM specifications, event-study combinations, final inference, table/figure generation, and verification in a separate private working directory. The model workflow proceeds through `monthly_analysis_journal.R` in `audit`, `models`, and `events` modes, then `monthly_inference_journal.R`, the output scripts, `verify_monthly.R`, and `check_event_warnings.R`. Event diagnostics use 1,999 multiplier-bootstrap iterations, so a complete run can take substantial time. Do not upload the private working directory or its observation-bearing caches.

### 3. Replay corrected source preprocessing

With the separately obtained reconstruction package:

```sh
Rscript OnlineResource2/source_preprocessing/replay_supplied.R /private/source-package /private/replay
```

Replay requires the listed daily-weather, monthly-pollution, coordinate, grid-weight, precipitation-check and annual-covariate inputs. This is reconstruction from supplied inputs, not a fresh independent aggregation of the entire original hourly archive. Optional nearest-panel construction and source verification require additional inputs and environment settings. Follow the [full reproduction guide](docs/REPRODUCIBILITY.md) and [input requirements](docs/DATA_ACCESS.md).

## Results and sensitivity analyses

All **4 main tables, 3 main figures, 12 supplementary tables, and 1 supplementary figure** are included. The [result index](docs/RESULTS_INDEX.md) provides their original captions/page previews, table or figure files, aggregate data, and generating scripts. Additional machine-readable outputs include all 60 seasonal pairwise comparisons, five pooled multiplicity-adjusted tests, all 34 station-validation summaries, and the May–June ozone specification.

The included analyses cover:

- **Spatial weights:** Row-standardized k-nearest-neighbor matrices with k = 3, 5, and 7.
- **Regional trends and cohort composition:** Cohort-specific linear trends and exclusion of individual designated cohorts.
- **Controls and observation period:** Transport-control omission, land-use-control omission, and a 2013–2024 starting-period comparison.
- **Interpolation:** Common-support IDW versus nearest-station fields, with and without cohort trends.
- **Policy timing:** Second-phase January 2018 and third-phase July or December 2020 assignments, with and without cohort trends.
- **Seasonal associations:** Separate winter, spring, summer, and autumn fits, covariance-aware comparisons, and a supplementary May–June ozone model.
- **Uncertainty:** Joint observed-information and calendar-month HAC bandwidths of 6, 12, and 24.

For the primary SDM results, select **`covariance == "HAC12"`** in [inference_impacts.csv](OnlineResource2/monthly_results/inference_impacts.csv) and [inference_coefficients.csv](OnlineResource2/monthly_results/inference_coefficients.csv). Preliminary uncertainty in `sdm_impacts.csv` and `sdm_raw.csv` is retained for reconstruction and is not the final manuscript inference. The main seasonal figure is **`Fig3_journal.pdf`**; `Fig3_seasonal.pdf` is an additional baseline-only output.

Holm adjustment uses separate families of 10 seasonal omnibus tests, 60 pairwise comparisons, and five pooled baseline tests. Displayed confidence intervals remain marginal, and interpolation-sensitivity fits are not presented as an additional confirmatory multiplicity family.

## Verification and interpretation

The public-package checks reproduced all 13 numerical table fragments, seasonal comparisons, timing outputs and interpolation-validation summaries. They also checked numerical consistency for 131 SDM outcome/specification combinations, 65 explicit spatial-matrix decompositions, and 40 seasonal marginal standard errors. A fresh baseline NO₂ fit was checked using separate private prepared inputs. The packaging checks did not newly re-estimate every model or rerun every bootstrap event study; original full-run reports are preserved separately. See the [verification report](docs/VERIFICATION.md) for the exact scope.

Pre-adoption diagnostics indicate systematic differences, and cohort-specific trends materially change some spatial estimates. Results should therefore be interpreted as **conditional spatial associations rather than definitive causal effects**. Score-HAC uncertainty is conditional on the prepared environmental fields and does not propagate interpolation error. Source-history limitations, the assumed third-phase common month, and the limits of source replay remain as described in the manuscript and Online Resource 1.

## Citation and availability

If you use these resources, please cite the associated manuscript and the actual repository release used:

> Lee, Minju, and Mijeong Kim. *Monitoring-based assessment of spatial and seasonal air-quality associations with low-emission zones in South Korea.*

Repository: [MJLee25/korea-lez-air-quality](https://github.com/MJLee25/korea-lez-air-quality). The code and aggregate results are prepared for a versioned public release upon publication. No publication DOI or release identifier is asserted by this local package. Machine-readable citation metadata are in [CITATION.cff](CITATION.cff); manuscript availability wording is in [CODE_AVAILABILITY.md](docs/CODE_AVAILABILITY.md).

Third-party source data remain subject to their providers' access and redistribution terms. This package does not distribute the restricted observation-level inputs or grant rights to redistribute them. A standalone code license has not been included in this prepared package.

For questions about the scripts or required input schema, contact the corresponding author, **Mijeong Kim** (m.kim@ewha.ac.kr), or open an issue in the public repository once available.
