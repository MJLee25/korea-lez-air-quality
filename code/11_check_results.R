#################################################
# 11. Results Verification
#################################################
# Run after setting the working directory to the repository root.
# Outputs: Numerical verification log

##### Packages
library(sf)
library(spdep)
library(dplyr)


#################################################
# Load Saved Results
#################################################

imp = subset(read.csv("result/_intermediate/inference_impacts.csv"), covariance ==
  "HAC12")

raw = subset(read.csv("result/_intermediate/inference_coefficients.csv"), covariance ==
  "HAC12")

pre = read.csv("result/_intermediate/event_summary.csv")

# The full parallel trends analysis sample must be retained after reloading the CSV.
stopifnot(all(pre$units == 247))

event = read.csv("result/_intermediate/event_dynamic.csv")
stopifnot(nrow(event) == 2180)

audit = read.csv("result/_intermediate/data_audit.csv")

overlap = read.csv("result/_intermediate/overlap_audit.csv")

summ = read.csv("result/_intermediate/summary_statistics.csv")

units = read.csv("result/_intermediate/cohort_membership.csv")

stopifnot(
  nrow(audit) == 2, all(audit$observations == audit$units * audit$months),
  all(audit$units == 247), all(audit$missing == 0), all(overlap$changed == 0),
  all(summ$pre_observations == 5478), identical(as.integer(table(units$g)), c(
    174L,
    25L, 35L, 13L
  )), nrow(pre) == 20, all(pre$covariance_rank <= pre$pre_restrictions),
  all(pre$max_t_p >= 5e-04), all(pre$max_t_p <= 1), all(is.finite(as.matrix(imp[c(
    "estimate",
    "se", "low", "high", "rho"
  )]))), all(imp$se > 0), all(abs(imp$rho) < 1),
  all(imp$n == imp$units * imp$periods), max(abs(imp$low - (imp$estimate - 1.96 *
    imp$se))) < 1e-09, max(abs(imp$high - (imp$estimate + 1.96 * imp$se))) <
    1e-09, max(abs(imp$relative_percent - 100 * imp$estimate / imp$pre_mean)) <
    1e-09
)


#################################################
# Verify the Sum of Spatial Effects
#################################################

keys = unique(imp[c("specification", "outcome")])

for (j in seq_len(nrow(keys))) {
  z = imp[imp$specification == keys$specification[j] & imp$outcome == keys$outcome[j], ]
  b = raw[raw$specification == keys$specification[j] & raw$outcome == keys$outcome[j], ]
  b = setNames(b$estimate, b$term)
  z = z[match(c("Direct", "Indirect", "Total"), z$component), ]
  stopifnot(
    nrow(z) == 3, abs(sum(z$estimate[1:2]) - z$estimate[3]) < 1e-09,
    abs((b["lez"] + b["w_lez"]) / (1 - b["lambda"]) - z$estimate[3]) < 1e-09
  )
}


#################################################
# Verify Spatial Effects Using Matrix Inversion
#################################################

xy = read.csv("data/analysis_coordinates.csv")

stopifnot(identical(xy$id, units$id), all(xy$epsg == 5179L))

coords = as.matrix(xy[c("x", "y")])

geo = units

errors = numeric()

for (s in c(
  "monthly", "k3", "k7", "omit61", "omit79", "omit97", "trends", "jan2018",
  "jan2018_trends", "jul2020", "jul2020_trends", "dec2020", "dec2020_trends"
)) {
  keep = if (startsWith(s, "omit")) {
    geo$g != as.numeric(sub("omit", "", s))
  } else {
    rep(TRUE, nrow(geo))
  }
  k = if (s == "k3") {
    3
  } else if (s == "k7") {
    7
  } else {
    5
  }
  W = listw2mat(nb2listw(knn2nb(knearneigh(coords[keep, , drop = FALSE], k = k)),
    style = "W"
  ))
  I = diag(nrow(W))
  stopifnot(max(abs(rowSums(W) - 1)) < 1e-12, all(diag(W) == 0))
  for (y in summ$outcome) {
    b = raw[raw$specification == s & raw$outcome == y, ]
    b = setNames(b$estimate, b$term)
    S = solve(I - b["lambda"] * W, b["lez"] * I + b["w_lez"] * W)
    direct = mean(diag(S))
    total = mean(rowSums(S))
    z = imp[imp$specification == s & imp$outcome == y, ]
    z = z[match(c("Direct", "Indirect", "Total"), z$component), ]
    errors = c(errors, max(abs(c(direct, total - direct, total) - z$estimate)))
  }
}

stopifnot(max(errors) < 1e-08)

stopifnot(nrow(keys) == 131)


#################################################
# Verify Districts, Months, and Annual Covariates across Both Panels
#################################################

idw = read.csv("data/02_final_data.csv", fileEncoding = "UTF-8-BOM", check.names = FALSE)

nearest = read.csv("data/nearest_panel.csv", fileEncoding = "UTF-8-BOM", check.names = FALSE)

stopifnot(nrow(idw) == 38844, nrow(nearest) == 38844)

stopifnot(identical(idw[1:6], nearest[1:6]))

annual = c(
  "pop_density", "industrial_area", "commercial_area", "green_area_per_capita",
  "daily_km", "cars_per_capita"
)

stopifnot(isTRUE(all.equal(idw[annual], nearest[annual], tolerance = 1e-10)))


#################################################
# Check Required Outputs
#################################################

expected = c(outer(
  c(paste("Table", 1:4), paste0("Table S", 1:11)), c(".csv", ".tex"),
  paste0
), outer(c("Fig 1", "Fig 2", "Fig 3", "Fig S1"), c(".png", ".pdf"), paste0))

stopifnot(all(file.exists(file.path("result", expected))))


#################################################
# Save Verification Results
#################################################

report = c(
  "Monthly analysis consistency verification: PASS", paste(
    "Verified SDM outcome/specification combinations:",
    nrow(keys)
  ), "All sample sizes, cohort counts, overlap audits and pre-adoption summaries match.",
  "All final HAC(12) SDM intervals, percentage scales and additive decompositions match.",
  paste(length(errors), "decompositions independently checked using explicit matrix inversion."),
  paste("Maximum explicit-inverse discrepancy:", format(max(errors), scientific = TRUE)),
  "These checks validate numerical consistency, not causal identification or source-data validity."
)

writeLines(report, "result/_checks/verification.txt")

capture.output(sessionInfo(), file = "result/_checks/sessionInfo.txt")

cat(paste(report, collapse = "\n"), "\n")
