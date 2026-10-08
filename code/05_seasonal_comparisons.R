#################################################
# 05. Cross-Season Comparisons and Multiple Testing Adjustment
#################################################

# Run after setting the working directory to the repository root.
# Outputs: Table S7, Pairwise seasonal comparisons, Holm adjustment for total effects


#################################################
# Define Seasons and Comparison Targets
#################################################

seasons = c("Winter", "Spring", "Summer", "Autumn")

outcomes = c("NO2", "CO", "SO2", "O3", "PM10")

months = list(Winter = c(12, 1, 2), Spring = 3:5, Summer = 6:8, Autumn = 9:11)

calendar = seq_len(156)

month = (calendar - 1) %% 12 + 1

kernel = pmax(1 - abs(outer(calendar, calendar, "-")) / 13, 0)

reported = read.csv("result/_intermediate/inference_impacts.csv")


#################################################
# Reconstruct Seasonal Influence Functions
#################################################

season_result = function(season, outcome, prefix) {
  x = readRDS(file.path("result/_intermediate", "model_information", paste0(
    prefix,
    season, "_", outcome, ".rds"
  )))
  b = subset(x$coefs, covariance == "HAC12")
  b = setNames(b$estimate, b$term)
  q = subset(x$impacts, covariance == "HAC12" & component == "Total")
  expected = reported[reported$specification == paste0(prefix, season) & reported$outcome ==
    outcome & reported$covariance == "HAC12" & reported$component == "Total", ]
  stopifnot(nrow(q) == 1L, nrow(expected) == 1L, abs(q$estimate - expected$estimate) <
    1e-08, abs(q$se - expected$se) < 1e-08)
  gradient = setNames(rep(0, nrow(x$information)), rownames(x$information))
  gradient["lambda"] = (b["lez"] + b["w_lez"]) / (1 - b["lambda"])^2
  gradient[c("lez", "w_lez")] = 1 / (1 - b["lambda"])
  centered = sweep(x$scores, 2, colMeans(x$scores), "-")
  a = as.vector(centered %*% solve(x$information, gradient))
  times = calendar[month %in% months[[season]]]
  stopifnot(length(times) == nrow(x$scores), length(a) == 39, nrow(q) == 1)
  influence = rep(0, length(calendar))
  influence[times] = a
  reconstructed_se = sqrt(as.numeric(crossprod(influence, kernel %*% influence)))
  stopifnot(abs(reconstructed_se - q$se) < 1e-07)
  list(estimate = q$estimate, influence = influence, se_error = abs(reconstructed_se -
    q$se))
}


#################################################
# Omnibus and Pairwise Seasonal Comparisons
#################################################

omnibus = pairwise = list()

errors = numeric()

for (prefix in c("", "trend_")) {
  for (y in outcomes) {
    label = if (prefix == "") {
      "Baseline"
    } else {
      "Cohort trends"
    }
    fits = lapply(seasons, season_result, outcome = y, prefix = prefix)
    estimates = vapply(fits, `[[`, numeric(1), "estimate")
    influence = do.call(cbind, lapply(fits, `[[`, "influence"))
    V = crossprod(influence, kernel %*% influence)
    C = cbind(-1, diag(3))
    difference = as.vector(C %*% estimates)
    VC = C %*% V %*% t(C)
    stopifnot(min(eigen(VC, symmetric = TRUE, only.values = TRUE)$values) >
      0)
    stat = as.numeric(crossprod(difference, solve(VC, difference)))
    omnibus[[length(omnibus) + 1]] = data.frame(
      specification = label, outcome = y,
      statistic = stat, df = 3, p = pchisq(stat, 3, lower.tail = FALSE)
    )
    for (ij in combn(4, 2, simplify = FALSE)) {
      i = ij[1]
      j = ij[2]
      delta = estimates[j] - estimates[i]
      se = sqrt(V[j, j] + V[i, i] - 2 * V[i, j])
      pairwise[[length(pairwise) + 1]] = data.frame(
        specification = label,
        outcome = y, contrast = paste(seasons[j], "minus", seasons[i]),
        estimate = delta, se = se, low = delta - 1.96 * se, high = delta +
          1.96 * se, p = 2 * pnorm(abs(delta / se), lower.tail = FALSE)
      )
    }
    errors = c(errors, vapply(fits, `[[`, numeric(1), "se_error"))
  }
}


#################################################
# Omnibus and Pairwise Seasonal Comparisons
#################################################

omnibus = do.call(rbind, omnibus)

pairwise = do.call(rbind, pairwise)

omnibus$p_holm = p.adjust(omnibus$p, "holm")

pairwise$p_holm = p.adjust(pairwise$p, "holm")

write.csv(omnibus, "result/_intermediate/seasonal_omnibus.csv", row.names = FALSE)

write.csv(pairwise, "result/_intermediate/seasonal_pairwise.csv", row.names = FALSE)


#################################################
# Holm Adjustment for Total Effects Reported in the Main Text
#################################################

pooled = read.csv("result/_intermediate/inference_impacts.csv")


#################################################
# Holm Adjustment for Total Effects Reported in the Main Text
#################################################

pooled = subset(pooled, specification == "monthly" & covariance == "HAC12" & component ==
  "Total")

pooled$p_holm = p.adjust(pooled$p, "holm")

write.csv(pooled, "result/_intermediate/pooled_multiplicity.csv", row.names = FALSE)


#################################################
# Save Table S7
#################################################

tex_y = setNames(c("NO$_2$", "CO", "SO$_2$", "O$_3$", "PM$_{10}$"), outcomes)

pval = function(x) ifelse(x < 0.001, "$<0.001$", sprintf("%.3f", x))

row = function(...) paste0(paste(c(...), collapse = " & "), " \\\\")

lines = c("\\begin{tabular}{llrrrr}", "\\toprule", row(
  "Specification", "Outcome",
  "$\\chi^2$", "df", "$p$", "Holm $p$"
), "\\midrule")

for (i in seq_len(nrow(omnibus))) {
  z = omnibus[i, ]
  lines = c(lines, row(
    z$specification, tex_y[z$outcome], sprintf("%.2f", z$statistic),
    z$df, pval(z$p), pval(z$p_holm)
  ))
  if (i == 5) {
    lines = c(lines, "\\midrule")
  }
}

writeLines(c(lines, "\\bottomrule", "\\end{tabular}"), "result/Table S7.tex")

report = c(
  "Joint seasonal comparison verification: PASS", "All 40 marginal SEs reproduce the previously reported HAC(12) values.",
  paste("Maximum marginal SE discrepancy:", format(max(errors), scientific = TRUE)),
  "Covariance includes cross-season dependence at the actual calendar gaps.",
  "Holm adjustment covers 10 omnibus tests and, separately, all 60 pairwise tests.",
  "Comparisons are exploratory and do not validate the fitted conditional mean."
)

writeLines(report, "result/_intermediate/seasonal_verification.txt")

print(omnibus, row.names = FALSE)

print(subset(pairwise, outcome == "O3" & grepl("Winter", contrast)), row.names = FALSE)

cat(paste(report, collapse = "\n"), "\n")

write.csv(omnibus, "result/Table S7.csv", row.names = FALSE)

write.csv(pairwise, "result/Table S7 - pairwise contrasts.csv", row.names = FALSE)

write.csv(pooled, "result/Table 3 - Holm adjustment.csv", row.names = FALSE)
