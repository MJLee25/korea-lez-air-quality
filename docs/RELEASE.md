# Publication release

1. Upload this repository's contents to `MJLee25/korea-lez-air-quality`; do not upload the separate review-data package, source inputs, local R library, or private reproduction directories.
2. Run `python scripts/verify_release.py` and the public reproduction command after a fresh clone. Preserve LF/CRLF bytes as declared in `.gitattributes` because aggregate cache signatures include MD5s of archived scripts/results.
3. Create an actual versioned GitHub release (for example `v1.0.0` when appropriate), identifying Online Resource 2 in its title and linking the result index. No tag or DOI is assigned by this preparation step.
4. If archiving through a DOI service, add the real DOI only after it is assigned. Update future-tense availability wording only after public release. Do not invent a repository DOI.
5. Review the intended reuse license before publication. This preparation does not grant a new open-source license for the authors' work or override third-party terms. The supplied journal class/style retain their own notices.

The GitHub Actions workflow checks file exclusions, checksums, result coverage and public numerical consistency. It does not gain access to private source data or re-estimate the restricted-input models.
