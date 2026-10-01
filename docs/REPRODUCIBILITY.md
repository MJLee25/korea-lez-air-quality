# Reproduction guide

## 1. Public aggregate-only reproduction

Requirements: Python 3.10+, R 4.6.x, Python `numpy`/`pandas`, R `dplyr`, `ggplot2`, `sf`, `spdep`. The submitted run used R 4.6.1 on macOS; see `OnlineResource2/monthly_results/sessionInfo.txt`. Current-package checks have their own report and do not replace that historical session record.

R must support Cairo (`capabilities("cairo")`) for embedded-font PDF output. Standard Windows R binaries used for this check support it. PDF export preserves the unit symbols without depending on a viewer's external Symbol font.

```sh
python -m pip install -r requirements.txt
Rscript scripts/install_dependencies.R public
python scripts/verify_release.py
python scripts/reproduce.py public
```

If Rscript is not on PATH, add `--rscript "C:/Program Files/R/R-4.6.0/bin/Rscript.exe"`. `--output PATH` chooses a new output directory; existing directories are refused to avoid mixing or overwriting runs. The public command creates a working copy of OnlineResource2, then runs:

1. `monthly_outputs_journal.R`: 10 table fragments and event/seasonal figures from final aggregate CSVs.
2. `seasonal_comparisons_journal.R`: 10 omnibus, 60 pairwise, 5 pooled Holm tests and the seasonal table, retaining cross-season covariance.
3. `journal_outputs.R`: the manuscript Figure 3 (40 seasonal estimates with/without cohort trends).
4. `timing_outputs.py`: 40 baseline/trend timing records and Table S12.
5. `validation_outputs.py`: Table S9 from all 34 archived validation summaries.
6. `verify_public.R`: 131 SDM combinations, intervals, additive decompositions, and 65 direct spatial-matrix inversions using public district coordinates.

Core analysis and inference files are byte-preserved because the aggregate-score caches validate their signatures. `.gitattributes` disables newline conversion for these archived inputs. Do not edit signatures to suppress a mismatch; regenerate the inference after a scientific code change. PDF/font rasterization may vary across operating systems; numerical comparisons use tolerances, while the original paper figures/tables remain archived.

## 2. Refit from private prepared inputs

This step re-estimates models; the public-only step above does not. Install the complete dependency set, then use an input directory containing all three files listed in DATA_ACCESS.md:

```sh
Rscript scripts/install_dependencies.R models
python scripts/reproduce.py probe --data-dir /private/prepared-inputs --output /private/lez-probe
python scripts/reproduce.py models --data-dir /private/prepared-inputs --output /private/lez-full-run
```

`probe` runs the data audit and one baseline NO2 fit. `models` runs all 131 SDM fits, all 20 event-study combinations (1,999 bootstrap draws), score-HAC inference, seasonal comparisons, result generation, and both numerical/event-warning checks. It can take substantial time. Failures stop the run and remain visible in the log. The runner uses a separate copy and never overwrites the distributed reference results. Result caches and input files in private run directories are not suitable for upload.

R model dependencies: `readxl`, `dplyr`, `tidyr`, `sf`, `spdep`, `splm`, `plm`, `did`, `ggplot2`, `geojsonsf`, `numDeriv`. `sf` and related packages may need system geospatial libraries on Linux. Original versions are recorded in sessionInfo.txt; the setup script installs available compatible packages rather than claiming a frozen historical environment.

## 3. Replay supplied source preprocessing

```sh
Rscript OnlineResource2/source_preprocessing/replay_supplied.R /private/source-package /private/replay
```

For nearest-panel construction (Bash example):

```sh
export LEZ_SOURCE_DIR=/private/source-package
export LEZ_STATION_INPUT=/private/replay/interpolation_station_input.csv
python /private/working-copy/OnlineResource2/analysis/build_nearest_panel.py
```

Run this on a private working copy: it writes an observation-level nearest panel. For source verification, set `LEZ_VALIDATION_OUTPUT=/private/validation`, replay to `/private/validation/reproduced`, then execute `analysis/reproduce_validation.py` in the private copy. Python `lxml` is additionally required. In PowerShell use `$env:LEZ_SOURCE_DIR = 'C:/private/source-package'` etc. The full reconstruction input list is in DATA_ACCESS.md.

Original hourly aggregation and complete historical station metadata are outside the independently replayed scope; the manuscript qualifications remain unchanged. No synthetic data are substituted for missing real inputs.

## 4. Manuscript source

`paper/` includes both LaTeX sources, original figure assets, table fragments, references and the supplied journal class. Run `pdflatex manuscript_ema`, `bibtex manuscript_ema`, then `pdflatex manuscript_ema` twice, and `pdflatex OnlineResource1` twice from `paper/` with a complete TeX installation. Availability paragraphs are revised; the original numerical content remains unchanged. `results/previews/` refers to submitted pages, not to a newly compiled revised manuscript.
