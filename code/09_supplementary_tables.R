#################################################
# 09. Station Validation and Policy Timing Sensitivity Tables
#################################################

# Run after setting the working directory to the repository root.
# Outputs: Table S8, Table S11

row_tex = function(...) paste0(paste(c(...), collapse = " & "), " \\\\")

num = function(x) sprintf("%.3f", x)

ys = c("NO2", "CO", "SO2", "O3", "PM10")

tex_y = setNames(c("NO$_2$", "CO", "SO$_2$", "O$_3$", "PM$_{10}$"), ys)


#################################################
# Table S8: Supplied Station Validation Summary
#################################################

cv = read.csv("data/support/station_validation_summary.csv", encoding = "UTF-8")

variables = c(
  paste0(ys, "_도시대기"), "avg_temp", "sun_time", "stagnant_days",
  "avg_wind", "avg_humid", "avg_rain"
)

labels = c(
  "NO$_2$ (ppb)", "CO (ppb)", "SO$_2$ (ppb)", "O$_3$ (ppb)", "PM$_{10}$ ($\\mu$g/m$^3$)",
  "Temperature ($^\\circ$C)", "Sunshine (h/day)", "Low-wind equivalent (days)",
  "Wind speed (m/s)", "Relative humidity (\\%)", "Precipitation (mm/day)"
)

lines = c(
  "\\begin{tabular}{@{}lrrrrr@{}}", "\\toprule", "& & \\multicolumn{2}{c}{IDW} & \\multicolumn{2}{c}{Nearest}\\\\",
  "Variable & Holdouts & MAE & RMSE & MAE & RMSE\\\\", "\\midrule"
)

for (i in seq_along(variables)) {
  a = cv[cv$variable == variables[i] & cv$method == "IDW", ]
  b = cv[cv$variable == variables[i] & cv$method == "Nearest", ]
  stopifnot(nrow(a) == 1, nrow(b) == 1, a$n == b$n)
  lines = c(lines, row_tex(labels[i], format(a$n,
    big.mark = ",", scientific = FALSE,
    trim = TRUE
  ), num(a$MAE), num(a$RMSE), num(b$MAE), num(b$RMSE)))
}

writeLines(c(lines, "\\bottomrule", "\\end{tabular}"), "result/Table S8.tex")

write.csv(cv, "result/_intermediate/interpolation_validation.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)


#################################################
# Table S11: Results under Alternative Policy Adoption Months
#################################################

imp = subset(read.csv("result/_intermediate/inference_impacts.csv"), covariance ==
  "HAC12" & component == "Total")

scenarios = data.frame(
  label = c(
    "Assigned months", "Phase 2: Jan. 2018", "Phase 3: July 2020",
    "Phase 3: Dec. 2020"
  ), base = c("monthly", "jan2018", "jul2020", "dec2020"),
  trend = c("trends", "jan2018_trends", "jul2020_trends", "dec2020_trends")
)

lines = character()

records = list()

for (j in seq_len(nrow(scenarios))) {
  s = scenarios[j, ]
  for (i in seq_along(ys)) {
    b = imp[imp$specification == s$base & imp$outcome == ys[i], ]
    t = imp[imp$specification == s$trend & imp$outcome == ys[i], ]
    stopifnot(nrow(b) == 1, nrow(t) == 1, b$n == 38532, t$n == 38532)
    cells = c(if (i == 1) {
      s$label
    } else {
      ""
    }, tex_y[ys[i]], sprintf("%.3f (%.3f)", b$estimate, b$se), sprintf(
      "[%.3f, %.3f]",
      b$low, b$high
    ), sprintf("%.3f (%.3f)", t$estimate, t$se), sprintf(
      "[%.3f, %.3f]",
      t$low, t$high
    ))
    lines = c(lines, row_tex(cells))
    records[[length(records) + 1]] = cbind(
      scenario = s$label, trend = FALSE,
      b
    )
    records[[length(records) + 1]] = cbind(
      scenario = s$label, trend = TRUE,
      t
    )
  }
  lines = c(lines, "\\addlinespace")
}

writeLines(lines, "result/_intermediate/timing_table_body.tex")

write.csv(do.call(rbind, records), "result/_intermediate/timing_sensitivity.csv",
  row.names = FALSE
)


#################################################
# Save CSV Files at Full Precision
#################################################

output = subset(cv, variable %in% variables & method %in% c("IDW", "Nearest"))

write.csv(output, "result/Table S8.csv", row.names = FALSE, fileEncoding = "UTF-8")


#################################################
# Save CSV Files at Full Precision
#################################################

output = do.call(rbind, records)

write.csv(output, "result/Table S11.csv", row.names = FALSE)

writeLines(c(
  "\\begin{longtable}{llrrrr}", "\\caption{Pooled total associations under alternative assigned rollout months}\\label{tab:s_timing}\\\\",
  "\\toprule", "Scenario & Outcome & Baseline (SE) & 95\\% interval & Cohort trends (SE) & 95\\% interval\\\\",
  "\\midrule\\endhead", lines, "\\bottomrule", "\\end{longtable}"
), "result/Table S11.tex")
