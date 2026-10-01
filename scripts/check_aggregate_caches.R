# Inspect every distributed RDS: only aggregate score/information objects are allowed.
arg <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
root <- normalizePath(file.path(dirname(arg), ".."))
out <- file.path(root, "OnlineResource2", "monthly_results")
files <- list.files(file.path(out, "inference_cache_journal"), pattern = "[.]rds$", full.names = TRUE)
stopifnot(length(files) == 131L)
allowed <- c("signature", "impacts", "coefs", "diagnostics", "covariances", "scores", "information")
expected <- unname(tools::md5sum(c(file.path(root, "OnlineResource2/analysis/monthly_inference_journal.R"),
    file.path(root, "OnlineResource2/analysis/monthly_analysis_journal.R"), file.path(out, "sdm_raw.csv"))))
for (f in files) {
  x <- readRDS(f)
  stopifnot(setequal(names(x), allowed), is.matrix(x$scores), nrow(x$scores) <= 156L,
    nrow(x$scores) >= 26L, ncol(x$scores) <= 40L,
    identical(dim(x$information), rep(ncol(x$scores), 2)),
    all(is.finite(x$scores)), all(is.finite(x$information)), nrow(x$impacts) == 12L,
    nrow(x$diagnostics) == 1L,
    identical(strsplit(x$signature, "|", fixed = TRUE)[[1]][1:3], expected))
  stopifnot(!any(grepl("residual|fitted|panel|station|influence", names(x), ignore.case = TRUE)))
}
cat("PASS: 131 aggregate cache schemas and archived code signatures; no observation-level objects.\n")
