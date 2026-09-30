Analysis code for the study:

**Pollutant-Specific and Spatial Air-Quality Responses to Low Emission Zones in South Korea: A Spatial Panel Analysis of Staggered Adoption**

## Overview

This repository contains the R code used for the main empirical analyses presented in the manuscript. The study examines pollutant-specific and spatial air-quality responses associated with South Korea's phased Low Emission Zone (LEZ) expansion over 2014–2024.

The analysis combines group-time event-study diagnostics for staggered LEZ adoption with non-spatial two-way fixed-effects (TWFE) models and spatial panel models. The repository also includes code for spatial autocorrelation diagnostics, robustness analyses using alternative spatial-weight matrices, and placebo tests.

### Data Sources

- **Air pollution**
  - **Source:** [AirKorea annual air-quality data](https://airkorea.or.kr/web/detailViewDown?pMENU_NO=125)
  - **Variables:** CO, SO2, NO2, O3, and PM10 concentrations
  - **Processing:** Station-level observations were spatially interpolated to si-gun-gu-level values using inverse-distance weighting (IDW; power = 2).
    
- **Meteorology**
  - **Source:** [KMA Open MET Data Portal](https://data.kma.go.kr/resources/html/en/ncdci.html)
  - **Variables:** Annual precipitation expressed as mm/day(`avg_rain`), annual average relative humidity(`annual_humid`), summer average temperature(`summer_temp`), winter average temperature(`winter_temp`), summer total sunshine duration(`summer_sun`), and stagnation days(`stagnation_days`).
  - Winter temperature was calculated using December of the preceding year and January–February of the current year, while summer temperature and sunshine duration were calculated using June–August of the current year.
  - **Construction:** Annual precipitation expressed as mm/day was estimated by diving annual total precipitation by 365 days. Atmospheric stagnation days were defined as days with mean wind speed ≤ 2 m/s.
  - **Processing:** Station-level observations were spatially interpolated to si-gun-gu-level values using IDW (power = 2).

- **Urban Structure**
  - **Sources:** [KOSIS/LX urban-area statistics](https://kosis.kr/statHtml/statHtml.do?orgId=101&tblId=DT_1YL20421E&conn_path=I3)
  - **Variables:** Population density(`pop_density`), industrial area(`industrial_area`), commercial area(`commercial_area`), and green area per capita(`green_area_per_capita`). Industrial, commercial, and green areas were expressed on a per-capita basis.
  - **Construction:** Population density was calculated as resident registered population divided by the land area (km²) of each si-gun-gu derived from the administrative boundary data. Green area was expressed on a per-capita basis.

- **Transportation**
  - **Sources:** [KOSIS road statistics](https://kosis.kr/statHtml/statHtml.do?orgId=101&tblId=DT_1YL20721&conn_path=I3), [KOSIS vehicles per capita](https://kosis.kr/statHtml/statHtml.do?orgId=101&tblId=DT_1YL20731&conn_path=I3), [Korea Transportation Safety Authority data](https://kosis.kr/statHtml/statHtml.do?sso=ok&returnurl=https%3A%2F%2Fkosis.kr%3A443%2FstatHtml%2FstatHtml.do%3Fconn_path%3DI3%26tblId%3DDT_426001_N004%26orgId%3D426%26)
  - **Variables:** Road paving rate(`road_paving_rate`), cars per capita (`cars_per_capita`), and average daily vehicle distance traveled(`daily_km`).
  - **Construction:** Cars per capita was calculated as registered vehicles divided by resident registered population. Average daily vehicle distance traveled is expressed in km per vehicle per day.
  - 
- **LEZ rollout**
  - **Source:** [MECAR old-diesel vehicle restriction information](https://www.mecar.or.kr/dr/info/oldDieselCarAlwaysDr.do)
  - **Treatment timing:** The LEZ was introduced sequentially in 2017, 2018, and 2020. The 2017 phase covered 25 Seoul districts; the 2018 expansion added 35 units in Incheon and selected Gyeonggi areas; and the 2020 expansion added 13 additional Gyeonggi units, resulting in 73 treated si-gun-gu units.
  - **Variables:**
    - `D1`: Cumulative LEZ coverage indicator for the first rollout phase. Equals 1 for Seoul units covered from 2017 onward and 0 otherwise.
    - `D2`: Cumulative LEZ coverage indicator for the second rollout phase. Equals 1 for units covered by 2018, including the `D1` units, Incheon (excluding Ongjin-gun), and selected Gyeonggi si-gun-gu units.
    - `D3`: Cumulative LEZ coverage indicator for the third rollout phase. Equals 1 for all units covered by 2020, including the `D2` units and additional Gyeonggi si-gun-gu units.
    - `D`: Time-invariant ever-treated indicator. Equals 1 if a si-gun-gu belongs to any of the three LEZ rollout phases and 0 for never-treated units.
    - `g`: First LEZ adoption year for each si-gun-gu (`2017`, `2018`, or `2020`); never-treated units are coded as `Inf` in the preprocessing data.
    - `g_cs`: First-treatment-year variable used for the *Callaway–Sant'Anna group-time DID analysis*. It corresponds to `g`, with never-treated units recoded to `0`.
    - `did`: Time-varying LEZ treatment indicator. Equals 0 before a unit's first treatment year and 1 from the treatment year onward; it remains 0 for never-treated units.
    - `w_did`: Spatially lagged LEZ exposure variable generated within `5_Spatial Staggered DID.R` script for each spatial-weight matrix. The baseline specification uses a row-standardized five-nearest-neighbor matrix (kNN, k = 5).


The final analysis sample consists of 247 si-gun-gu units observed annually from 2014 to 2024, excluding Ongjin-gun and Ulleung-gun. The analysis scripts require two input files:

- `dat.xlsx`: the processed si-gun-gu-year panel containing outcomes, treatment variables, and covariates.
- `korea.geojson`: the si-gun-gu administrative boundary file used for spatial operations and construction of spatial weight matrices.

The numeric panel identifier (`id`) was constructed from the si-gun-gu administrative code. Unique administrative codes were sorted in ascending order and assigned sequential integer IDs. The resulting identifier is constant for each si-gun-gu across all years and is used as the panel index in the DID and spatial panel models.

Due to licensing and data-sharing restrictions, these input datasets are **not** included in this repository. Users should obtain the original data from the corresponding public agencies before running the replication code.

## Repository Structure

```text
├── code
│   ├── 1_parallel_trend.R
│   ├── 2_global morans I.R
│   ├── 3_LM Test.R
│   ├── 4_TWFE-DID.R
│   ├── 5_Spatial Staggered DID.R
│   └── 6_Placebo Test.R
│
├── README.md
└── sessionInfo.txt
```

## Software Requirements

* R (version 4.3 or later recommended)

Main R packages include:

* `readxl`
* `sf`
* `dplyr`
* `spdep`
* `splm`
* `plm`
* `did`
* `ggplot2`
* `MASS`
* `tidyr`
* `purrr`
* `gridExtra`
* `geojsonsf`

For the exact R environment and package versions used in the analysis, see [`sessionInfo.txt`](sessionInfo.txt).

## Replication

Run the scripts in the following order:

1. `1_parallel_trend.R`
2. `2_global morans I.R`
3. `3_LM Test.R`
4. `4_TWFE-DID.R`
5. `5_Spatial Staggered DID.R`
6. `6_Placebo Test.R`

Conditional on the required processed input files, the scripts reproduce the main statistical analyses and selected robustness checks reported in the manuscript.

`5_Spatial Staggered DID.R` also contains the following robustness analyses:

- **Alternative spatial-weight matrices:** kNN (k = 3, 5, 7) and inverse-distance cutoff matrices (50 km and 70 km).

*By default, the script estimates the SDM using kNN matrices with k = 3, 5, and 7 and inverse-distance cutoff matrices of 50 km and 70 km. Because estimating all specifications with simulation-based spatial impacts may be time-consuming, users interested only in the baseline specification can run the kNN k = 5 model (`final_k5`, `listw_k5`, and `res_k5`) and skip the alternative weight-matrix models.*
- **COVID-19 sensitivity:** uncomment the annotated filter excluding 2020–2022.  *line 23*
- **Precipitation sensitivity:** uncomment the annotated specifications excluding `avg_rain` from `climate`, `vars`, and `w_climate`.  *line 105-106, 155*

## Important Interpretation Note

The group-time event-study diagnostic rejects joint parallel trends for all five pollutants in the current analysis. Cohort-specific linear-trend sensitivity checks also materially alter the baseline spatial estimates. Results should therefore be interpreted as conditional spatial policy associations rather than definitive causal effects.

## Citation

If you use this code, please cite the corresponding article:

> **Minju Lee, Mijeong Kim,** *Pollutant-Specific and Spatial Air-Quality Responses to Low Emission Zones in South Korea: A Spatial Panel Analysis of Staggered Adoption* (Manuscript under review.)

## License

The MIT License applies to repository code only. It does not grant rights to third-party source data.

## Contact

Please open a GitHub issue or contact the corresponding author for questions about the scripts or required input schema.
