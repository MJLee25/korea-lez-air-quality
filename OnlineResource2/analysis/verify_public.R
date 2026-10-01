# Public aggregate-only adapter of verify_monthly.R.
suppressPackageStartupMessages({library(sf); library(spdep); library(dplyr)})
arg <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
paper <- normalizePath(file.path(dirname(arg), ".."))
out <- file.path(paper, "monthly_results")
read_result <- function(name) read.csv(file.path(out, paste0(name, ".csv")))
imp <- subset(read_result("inference_impacts"), covariance == "HAC12")
raw <- subset(read_result("inference_coefficients"), covariance == "HAC12")
pre <- read_result("event_summary")
audit <- read_result("data_audit")
overlap <- read_result("overlap_audit")
summ <- read_result("summary_statistics")
units <- read_result("cohort_membership")
stopifnot(nrow(audit) == 2, all(audit$observations == audit$units * audit$months),
  all(audit$units == 247), all(audit$missing == 0), all(overlap$changed == 0),
  all(summ$pre_observations == 5478),
  identical(as.integer(table(units$g)), c(174L, 25L, 35L, 13L)),
  nrow(pre) == 20, all(pre$covariance_rank <= pre$pre_restrictions),
  all(pre$max_t_p >= .0005), all(pre$max_t_p <= 1),
  all(is.finite(as.matrix(imp[c("estimate", "se", "low", "high", "rho")]))),
  all(imp$se > 0), all(abs(imp$rho) < 1), all(imp$n == imp$units * imp$periods),
  max(abs(imp$low - (imp$estimate - 1.96 * imp$se))) < 1e-9,
  max(abs(imp$high - (imp$estimate + 1.96 * imp$se))) < 1e-9,
  max(abs(imp$relative_percent - 100 * imp$estimate / imp$pre_mean)) < 1e-9)

keys <- unique(imp[c("specification", "outcome")])
for (j in seq_len(nrow(keys))) {
  z <- imp[imp$specification == keys$specification[j] & imp$outcome == keys$outcome[j], ]
  b <- raw[raw$specification == keys$specification[j] & raw$outcome == keys$outcome[j], ]
  b <- setNames(b$estimate, b$term)
  z <- z[match(c("Direct", "Indirect", "Total"), z$component), ]
  stopifnot(nrow(z) == 3, abs(sum(z$estimate[1:2]) - z$estimate[3]) < 1e-9,
    abs((b["lez"] + b["w_lez"]) / (1 - b["lambda"]) - z$estimate[3]) < 1e-9)
}

# Check the eigenvalue-based decomposition against an explicit matrix inverse.
xy <- read.csv(file.path(out, "analysis_coordinates.csv"))
stopifnot(identical(xy$id, units$id), all(xy$epsg == 5179L))
coords <- as.matrix(xy[c("x", "y")])
geo <- units
errors <- numeric()
for (s in c("monthly", "k3", "k7", "omit61", "omit79", "omit97", "trends",
  "jan2018", "jan2018_trends", "jul2020", "jul2020_trends", "dec2020", "dec2020_trends")) {
  keep <- if (startsWith(s, "omit")) geo$g != as.numeric(sub("omit", "", s)) else rep(TRUE, nrow(geo))
  k <- if (s == "k3") 3 else if (s == "k7") 7 else 5
  W <- listw2mat(nb2listw(knn2nb(knearneigh(coords[keep, , drop = FALSE], k = k)), style = "W"))
  I <- diag(nrow(W))
  stopifnot(max(abs(rowSums(W) - 1)) < 1e-12, all(diag(W) == 0))
  for (y in summ$outcome) {
    b <- raw[raw$specification == s & raw$outcome == y, ]; b <- setNames(b$estimate, b$term)
    S <- solve(I - b["lambda"] * W, b["lez"] * I + b["w_lez"] * W)
    direct <- mean(diag(S)); total <- mean(rowSums(S))
    z <- imp[imp$specification == s & imp$outcome == y, ]
    z <- z[match(c("Direct", "Indirect", "Total"), z$component), ]
    errors <- c(errors, max(abs(c(direct, total - direct, total) - z$estimate)))
  }
}
stopifnot(max(errors) < 1e-8)
report <- c("Monthly analysis consistency verification: PASS",
  paste("Verified SDM outcome/specification combinations:", nrow(keys)),
  "All sample sizes, cohort counts, overlap audits and pre-adoption summaries match.",
  "All final HAC(12) SDM intervals, percentage scales and additive decompositions match.",
  paste(length(errors), "decompositions independently checked using explicit matrix inversion."),
  paste("Maximum explicit-inverse discrepancy:", format(max(errors), scientific = TRUE)),
  "These checks validate numerical consistency, not causal identification or source-data validity.")
writeLines(report, file.path(out, "verification.txt"))
cat(paste(report, collapse = "\n"), "\n")
