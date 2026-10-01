# Public packaging changes

- Core estimation, HAC inference, seasonal inference, and corrected preprocessing transformations are byte-preserved from submitted Online Resource 2.
- `validation_outputs.py` reads the bundled audit summary by default; `LEZ_VALIDATION_CSV` allows an explicit alternative. Its submitted version is preserved in provenance.
- PDF figure exports use the Cairo device to embed fonts and preserve mathematical unit symbols across PDF viewers. The two original figure/table scripts are retained in provenance; plot data and table calculations are unchanged.
- `verify_public.R` is a separate adapter of `verify_monthly.R`: it uses the included district centroid metadata and removes the irrelevant requirement that a private observation panel merely exist. Scientific numerical checks are unchanged.
- The replay wrapper invokes the bundled corrected preprocessing code and validates its argument count. The supplied wrapper and launcher remain available for provenance. No scientific preprocessing formula is changed.
- An isolated Python runner, input schema, dependency installer, public-file check, checksum manifest, result inventory and documentation are added.
- All 16 main/supplementary tables and 4 figures are included; 3 static evidence/definition tables are extracted verbatim. Additional result CSVs, scores and audit reports are retained.
- Data availability and Code availability alone are updated in the manuscript to name the future repository and distinguish public aggregate outputs from restricted prepared panels. Online Resource 1 is unchanged.

Historical verification reports in `OnlineResource2/monthly_results/` are supplied evidence. The current release test report in `docs/VERIFICATION.md` states what was rerun during public packaging. No public upload was performed.
