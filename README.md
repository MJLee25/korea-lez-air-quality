# Air Quality and Low-Emission Zones in South Korea
This repository contains the analysis code and result tables for the paper:

**Monitoring-based assessment of spatial and seasonal air-quality associations with low-emission zones in South Korea**

R scripts for assessing spatial and seasonal associations between permanent low-emission zone (LEZ) rollout and air quality across 247 South Korean districts during 2012–2024.

The analysis covers NO₂, CO, SO₂, O₃, and PM₁₀. Estimates are interpreted as conditional associations rather than causal policy effects.

## Scripts

| Script | Description |
|---|---|
| `01_data_preparation.R` | Constructs analysis panels, assigns policy cohorts, and checks data completeness and consistency. |
| `02_parallel_trends.R` | Estimates group-time and event-time contrasts and conducts pre-adoption trend tests. |
| `03_spatial_models.R` | Fits spatial Durbin and non-spatial models, including seasonal and sensitivity specifications. |
| `04_hac_inference.R` | Computes HAC standard errors for spatial associations and examines residual dependence. |
| `05_seasonal_comparisons.R` | Tests cross-season differences and applies Holm adjustments for multiple testing. |
| `06_model_tables.R` | Exports main and supplementary model results as LaTeX and CSV tables. |
| `07_figures.R` | Produces event-study and seasonal comparison figures (Figures 2, 3, and S1). |
| `08_study_map.R` | Maps the study area and policy adoption cohorts (Figure 1). |
| `09_supplementary_tables.R` | Exports station prediction validation and policy timing sensitivity results (Tables S8 and S11). |
| `10_descriptive_tables.R` | Exports covariate definitions, policy timing evidence, and an unnumbered verification-scope reference. |
| `11_check_results.R` | Checks numerical consistency, sample composition, and required output files. |

## Running the Analysis

Required R packages include `dplyr`, `tidyr`, `did`, `spdep`, `splm`, `plm`, `numDeriv`, `ggplot2`, and `sf`. Input files must be available at the paths specified in the scripts.

The `data/` directory and the derived datasets `result/_intermediate/analysis_panel.csv` and `result/_intermediate/nearest_analysis_panel.csv` are excluded from this repository due to copyright and redistribution restrictions.

## Outputs
- `result/`: manuscript tables, figures, and associated CSV files.
- `result/_intermediate/`: estimates, diagnostic results, and saved model information; analysis panels are excluded.
- `result/_checks/`: Figure 1 cohort mapping, package versions, and R session information.

Outputs follow the manuscript numbering: Tables 1–4, Tables S1–S11, and Figures 1–3 and S1.
