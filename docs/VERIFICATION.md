# Verification of the public package

Completed locally on 30 September 2026. The current packaging run is distinguished
from the original full-analysis reports archived in Online Resource 2.

| Check | Result |
|---|---|
| Public-only workflow, with no observation panels in the run directory | PASS: all seven steps completed |
| Numerical LaTeX fragments | All 13 regenerated fragments match the submitted fragments after newline decoding |
| Seasonal tests | 10 omnibus, 60 pairwise, 5 pooled Holm-adjusted results match the reference CSVs within 1e-9 tolerance |
| Timing and source-validation table inputs | 40 timing rows and all 34 validation summaries match |
| Statistical figures | Main Figures 2 and 3 and Supplementary Figure S1 regenerated; PDF export embeds fonts through Cairo |
| SDM numerical consistency | 131 outcome/specification combinations; interval, sample-size, scaling and decomposition checks pass |
| Spatial matrix inverse checks | 65 decompositions; maximum discrepancy 4.440892e-14 |
| Seasonal marginal SE reconstruction | 40 comparisons pass using the aggregate scores and joint information |
| Private prepared-data smoke run | Data audit and a fresh baseline NO2 fit completed; maximum direct/indirect/total point-estimate difference 7.483e-14 |
| Distributed RDS objects | All 131 cache schemas and archived-code signatures checked; aggregate monthly scores/information only |
| Result coverage | All 4 main tables, 3 main figures, 12 supplementary tables, and 1 supplementary figure included |
| Scientific-file preservation | All supplied monthly-result files and validation summaries byte-identical; core estimation/inference/seasonal code byte-identical |
| Manuscript changes | Only Data availability and Code availability change; Online Resource 1 byte-identical |

Evidence: [public run report](verification/public_run_report.json),
[private probe report](verification/private_probe_report.json),
[probe comparison](verification/probe_point_estimate_comparison.csv),
[matrix verification](verification/verification.txt),
[seasonal verification](verification/seasonal_verification.txt),
[file provenance comparison](../OnlineResource2/provenance/public_packaging_comparison.json),
and [aggregate CSV inventory](aggregate_file_catalog.csv).

## Scope

This packaging run did **not** re-estimate all 131 models, rerun all 20 bootstrap
event studies, replay source preprocessing, or independently reacquire the full
hourly archive. Original reports document the submitted full run; the current
run regenerates public outputs and checks their numerical consistency, plus one
fresh private-data model. Figure 1 and three evidence/definition tables are
preserved assets. No new causal-identification or source-license claim is made.

The revised LaTeX manuscript was checked for a two-paragraph-only edit. A new
full manuscript PDF was not compiled in this environment; submitted-page result
previews remain identified as submitted previews. Existing table/figure content
and the source required for compilation are included.

The current run used Windows R 4.6.0 with public-output packages dplyr 1.2.1,
ggplot2 4.0.3, sf 1.1-3 and spdep 1.4-2. Packages built for R 4.6.1 produced version
warnings but completed successfully. The private probe used splm 1.6-5; its
package installation includes did 2.5.1, whereas the submitted full event run
records did 2.3.0. Full bootstrap refitting under that changed dependency version
is not represented as tested. The original sessionInfo.txt remains preserved.

Run `python scripts/verify_release.py` after download/clone to check the complete
SHA-256 manifest, file exclusions, table/figure coverage, and public numerical
identities. Run `Rscript scripts/check_aggregate_caches.R` to inspect cache schemas
and signatures. The public reproduction command invokes this cache check too.
