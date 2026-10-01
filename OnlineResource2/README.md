# Online Resource 2

This directory is **Online Resource 2 cited in the manuscript and Online Resource 1**. It supplies estimation, inference, interpolation-sensitivity, seasonal-comparison, verification, and corrected preprocessing code, together with aggregate results and provenance.

**[All manuscript results](../docs/RESULTS_INDEX.md)** · **[Run the code](../docs/REPRODUCIBILITY.md)** · **[Input requirements](../docs/DATA_ACCESS.md)** · **[Checks](../docs/VERIFICATION.md)**

The submitted scientific scripts and result CSVs are preserved. Public packaging adds a path-portable validation formatter and a separate aggregate-only numerical verifier. The core estimation/inference scripts remain byte-identical so their cache signatures remain valid. See [changes and provenance](../docs/CHANGES.md).

| Content | Purpose |
|---|---|
| `analysis/` | Estimation, event diagnostics, HAC inference, seasonal tests, figures, tables, validation |
| `monthly_results/` | Aggregate coefficients, impacts, event estimates, tests, audits, original numerical verification reports |
| `monthly_results/inference_cache_journal/` | Per-fit aggregate monthly scores, information and covariance matrices, and aggregate estimates; no district-observation panels |
| `source_preprocessing/` | Supplied corrected preprocessing scripts and isolated replay wrapper |
| `validation_evidence/` | Archived independent source-audit summaries (not raw observations) |
| `provenance/` | Original checksums, supplied manifest, and original versions of path-adapted scripts |
| `tables/` | The 13 generated numerical table fragments |

The 131 SDM specifications/outcomes and 20 event-study combinations use corrected release `20260920-re`. Primary inference uses HAC(12). Seasonal omnibus, pairwise, and pooled tests use separate Holm families of 10, 60, and 5 tests; intervals remain marginal.

Run `python scripts/reproduce.py public` from the repository root. Read the reproduction guide before model refitting or source replay. The separate review-data package is not part of this public directory and must never be uploaded with it.

The submitted archive manifest is retained under `provenance/submitted_manifest_sha256.csv` as historical evidence; the current public-release manifest is `../manifest_sha256.csv`.
