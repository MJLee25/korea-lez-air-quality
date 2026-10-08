#################################################
# 06. Main and Supplementary Model Results Tables
#################################################

# Run after setting the working directory to the repository root.
# Outputs: Table 1, 3, 4, S1–S6, S9 (TEX and CSV)

library(dplyr)


#################################################
# Load Estimation Results
#################################################

inference = read.csv("result/_intermediate/inference_impacts.csv")
imp = subset(inference, covariance == "HAC12")

tw = read.csv("result/_intermediate/sdm_twfe.csv")

raw = subset(
  read.csv("result/_intermediate/inference_coefficients.csv"),
  covariance == "HAC12"
)

pre = read.csv("result/_intermediate/event_summary.csv")
summ = read.csv("result/_intermediate/summary_statistics.csv")

diagnostics = subset(
  read.csv("result/_intermediate/residual_diagnostics.csv"),
  specification == "monthly"
)


#################################################
# Variable Labels and Shared Functions
#################################################

ys = c("NO2", "CO", "SO2", "O3", "PM10")
components = c("Direct", "Indirect", "Total")

tex_y = setNames(
  c("NO$_2$", "CO", "SO$_2$", "O$_3$", "PM$_{10}$"),
  ys
)

plot_y = setNames(
  c(
    "NO[2]~(ppb)", "CO~(ppb)", "SO[2]~(ppb)",
    "O[3]~(ppb)", "PM[10]~(mu*g~m^{-3})"
  ),
  ys
)

num = function(x, digits = 3) {
  ifelse(is.na(x), "n.a.", formatC(x, format = "f", digits = digits))
}

pval = function(p) {
  ifelse(is.na(p), "n.a.", ifelse(p < 0.001, "<0.001", num(p, 4)))
}

row = function(...) {
  paste0(paste(c(...), collapse = " & "), " \\\\")
}

stars = function(p) {
  ifelse(
    is.na(p), "",
    ifelse(
      p < 0.01, "***",
      ifelse(p < 0.05, "**", ifelse(p < 0.10, "*", ""))
    )
  )
}

# TEX: estimates with superscript significance stars
coef_star = function(estimate, p, digits = 3) {
  stopifnot(length(estimate) == length(p))
  s = stars(p)
  s[is.na(estimate)] = ""
  
  paste0(
    num(estimate, digits),
    ifelse(s == "", "", paste0("$^{", s, "}$"))
  )
}

## p-value
pval_star = function(p) {
  s = stars(p)
  
  ifelse(
    is.na(p),
    "n.a.",
    paste0(
      "$", pval(p),
      ifelse(s == "", "", paste0("^{", s, "}")),
      "$"
    )
  )
}

se_text = function(se) {
  paste0("(", num(se), ")")
}

# Verify that each requested row exists exactly once and sort the rows
ordered_rows = function(z, key, values) {
  stopifnot(
    nrow(z) == length(values),
    !anyNA(z[[key]]),
    !anyDuplicated(z[[key]]),
    setequal(as.character(z[[key]]), values)
  )
  
  z[match(values, z[[key]]), , drop = FALSE]
}

# Validate p-values for significance stars; allow NA values without stars
check_p = function(z, column = "p") {
  stopifnot(column %in% names(z), is.numeric(z[[column]]))
  p = z[[column]]
  stopifnot(all(is.na(p) | (is.finite(p) & p >= 0 & p <= 1)))
}

check_p(imp)
check_p(tw)
check_p(raw)
check_p(inference)
check_p(pre, "max_t_p")

note_row = function(text, ncols) {
  paste0(
    "\\multicolumn{", ncols,
    "}{l}{\\footnotesize ", text, "} \\\\"
  )
}

star_note = function(ncols) {
  note_row(
    "$^{*}p<0.10$, $^{**}p<0.05$, $^{***}p<0.01$.",
    ncols
  )
}

save_tex = function(lines, name, ncols, notes = character(),
                    significance = FALSE) {
  footer = "\\bottomrule"
  
  if (length(notes) > 0) {
    footer = c(
      footer,
      vapply(notes, note_row, character(1), ncols = ncols)
    )
  }
  
  if (significance) {
    footer = c(footer, star_note(ncols))
  }
  
  writeLines(
    c(lines, footer, "\\end{tabular}"),
    file.path("result", paste0(name, ".tex"))
  )
}

# CSV: preserve the original numeric columns and add display columns only
add_sig_columns = function(z) {
  check_p(z)
  stopifnot("estimate" %in% names(z))
  
  z$stars = stars(z$p)
  z$stars[is.na(z$estimate)] = ""
  z$estimate_display = paste0(num(z$estimate), z$stars)
  z
}

save_csv = function(z, name) {
  write.csv(
    z,
    file.path("result", paste0(name, ".csv")),
    row.names = FALSE,
    na = ""
  )
}


#################################################
# Table 1. Descriptive Statistics: no significance stars
#################################################

lines = c(
  "\\begin{tabular}{lrrrrr}",
  "\\toprule",
  row("Outcome", "Mean", "SD", "Minimum", "Maximum", "Pre-LEZ mean"),
  "\\midrule"
)

for (y in ys) {
  z = summ[summ$outcome == y, ]
  stopifnot(nrow(z) == 1)
  
  lines = c(
    lines,
    row(
      tex_y[y], num(z$mean), num(z$sd),
      num(z$min), num(z$max), num(z$treated_pre_mean)
    )
  )
}

save_tex(lines, "Table 1", 6)
save_csv(summ, "Table 1")


#################################################
# Table 3. Non-Spatial Benchmark and Spatial Effects
#################################################

primary = subset(imp, specification == "monthly")
twfe = subset(tw, specification == "monthly")

lines = c(
  "\\begin{tabular}{lrrrrr}",
  "\\toprule",
  row(
    "Outcome", "TWFE", "Direct",
    "Indirect", "Total", "Total/mean (\\%)"
  ),
  "\\midrule"
)

for (y in ys) {
  z = ordered_rows(
    primary[primary$outcome == y, ],
    "component",
    components
  )
  
  t = twfe[twfe$outcome == y, ]
  stopifnot(nrow(t) == 1)
  
  lines = c(
    lines,
    row(
      tex_y[y],
      coef_star(t$estimate, t$p),
      coef_star(z$estimate, z$p),
      num(z$relative_percent[3], 1)
    ),
    row("", se_text(t$se), se_text(z$se), ""),
    "\\addlinespace[3pt]"
  )
}

save_tex(
  lines, "Table 3", 6,
  notes = c(
    "Standard errors in parentheses.",
    "TWFE: unit-clustered SEs; spatial effects: HAC(12) SEs."
  ),
  significance = TRUE
)

primary_csv = add_sig_columns(primary)
twfe_csv = add_sig_columns(twfe)

for (nm in c("estimate", "se", "p", "stars", "estimate_display")) {
  names(twfe_csv)[names(twfe_csv) == nm] = paste0("twfe_", nm)
}

output = merge(
  primary_csv,
  twfe_csv,
  by = c("specification", "outcome"),
  all.x = TRUE,
  sort = FALSE
)

output = output[
  order(
    match(output$outcome, ys),
    match(output$component, components)
  ),
]

save_csv(output, "Table 3")


#################################################
# Table 4, S3, S9. Compare Sensitivity Models
#################################################

spec_labels = c(
  monthly = "Monthly baseline",
  trends = "Cohort trends",
  no_transport = "Omit transport controls",
  k3 = "$k=3$",
  k7 = "$k=7$",
  omit61 = "Omit Seoul cohort",
  omit79 = "Omit July 2018 cohort",
  omit97 = "Omit January 2020 cohort",
  start2013 = "Start in 2013",
  core2024 = "Omit land-use controls",
  jan2018 = "2018 cohort starts January",
  nearest = "Nearest interpolation",
  nearest_trends = "Nearest + cohort trends"
)

make_spec_table = function(names_use, name, include_se = TRUE,
                           labels = spec_labels) {
  stopifnot(all(names_use %in% names(labels)))
  
  lines = c(
    "\\begin{tabular}{lrrrrr}",
    "\\toprule",
    row("Specification", tex_y),
    "\\midrule"
  )
  
  csv_rows = vector("list", length(names_use))
  
  for (i in seq_along(names_use)) {
    s = names_use[i]
    
    z = ordered_rows(
      imp[imp$specification == s & imp$component == "Total", ],
      "outcome",
      ys
    )
    
    lines = c(
      lines,
      row(labels[s], coef_star(z$estimate, z$p))
    )
    
    if (include_se) {
      lines = c(
        lines,
        row("", se_text(z$se)),
        "\\addlinespace[3pt]"
      )
    }
    
    csv_rows[[i]] = add_sig_columns(z)
  }
  
  notes = if (include_se) {
    "HAC(12) standard errors in parentheses."
  } else {
    "Significance based on HAC(12) p-values."
  }
  
  save_tex(lines, name, 6, notes = notes, significance = TRUE)
  save_csv(bind_rows(csv_rows), name)
}

make_spec_table(
  c("monthly", "trends", "omit61", "omit79", "omit97"),
  "Table 4"
)

make_spec_table(
  c("k3", "k7", "no_transport", "start2013", "core2024", "jan2018"),
  "Table S3"
)

make_spec_table(
  c("monthly", "nearest", "trends", "nearest_trends"),
  "Table S9",
  labels = c(
    monthly = "IDW baseline",
    nearest = "Nearest baseline",
    trends = "IDW + cohort trends",
    nearest_trends = "Nearest + cohort trends"
  )
)


#################################################
# Table S1. Pre-Trend Tests
#################################################
lines = c(
  "\\begin{tabular}{llrrrrr}",
  "\\toprule",
  row("Period", "Estimator", tex_y),
  "\\midrule"
)

period_labels = c(
  dat12_24 = "2012--2024",
  dat13_24 = "2013--2024",
  dat12_25 = "2012--2025"
)

for (nm in c("dat12_24", "dat13_24")) {
  for (method in c("reg", "dr")) {
    z = ordered_rows(
      pre[pre$dataset == nm & pre$estimator == method, ],
      "outcome",
      ys
    )
    
    lines = c(
      lines,
      row(period_labels[nm], method, pval_star(z$max_t_p))
    )
  }
}

save_tex(
  lines, "Table S1", 7,
  notes = c(
    "Entries are pre-trend test p-values.",
    "Stars indicate rejection of the pre-trend test null."
  ),
  significance = TRUE
)

output = pre
output$max_t_stars = stars(output$max_t_p)
output$max_t_p_display = paste0(
  pval(output$max_t_p),
  output$max_t_stars
)

save_csv(output, "Table S1")


#################################################
# Table S2. Seasonal Spatial Effects
#################################################

seasons = c("Winter", "Spring", "Summer", "Autumn")

lines = c(
  "\\begin{tabular}{llrrrr}",
  "\\toprule",
  row(
    "Season", "Outcome", "Direct",
    "Indirect", "Total", "Trend-adjusted total"
  ),
  "\\midrule"
)

for (s in seasons) {
  for (y in ys) {
    z = ordered_rows(
      imp[imp$specification == s & imp$outcome == y, ],
      "component",
      components
    )
    
    tr = imp[
      imp$specification == paste0("trend_", s) &
        imp$outcome == y &
        imp$component == "Total",
    ]
    
    stopifnot(nrow(tr) == 1)
    
    lines = c(
      lines,
      row(
        if (y == ys[1]) s else "",
        tex_y[y],
        coef_star(z$estimate, z$p),
        coef_star(tr$estimate, tr$p)
      ),
      row("", "", se_text(z$se), se_text(tr$se))
    )
  }
  
  lines = c(lines, "\\addlinespace[4pt]")
}

save_tex(
  lines, "Table S2", 6,
  notes = "HAC(12) standard errors in parentheses.",
  significance = TRUE
)

output = subset(
  imp,
  specification %in% seasons |
    (specification %in% paste0("trend_", seasons) &
       component == "Total")
)

save_csv(add_sig_columns(output), "Table S2")


#################################################
# Table S4. Coefficients with Standardized Covariates
#################################################

coef_names = c(
  lambda = "$\\rho$",
  lez = "LEZ",
  pop_density = "Population density",
  industrial_area = "Industrial area/person",
  commercial_area = "Commercial area/person",
  green_area_per_capita = "Green area/person",
  daily_km = "Daily vehicle distance",
  cars_per_capita = "Cars/person",
  avg_temp = "Temperature",
  sun_time = "Sunshine",
  stagnant_days = "Low-wind equivalent days",
  avg_wind = "Wind speed",
  avg_humid = "Humidity",
  avg_rain = "Precipitation"
)

terms = raw$term[
  raw$specification == "monthly" & raw$outcome == "NO2"
]

lines = c(
  "\\begin{longtable}{lrrrrr}",
  "\\caption{Monthly SDM coefficients with standardized covariates}\\label{tab:s_coefficients}\\\\",
  "\\toprule",
  row("Term", tex_y),
  "\\midrule\\endfirsthead",
  "\\multicolumn{6}{c}{Table S4 (continued)}\\\\",
  "\\toprule",
  row("Term", tex_y),
  "\\midrule\\endhead",
  "\\bottomrule",
  "\\endfoot",
  "\\bottomrule",
  note_row("HAC(12) standard errors in parentheses.", 6),
  star_note(6),
  "\\endlastfoot"
)

for (term in terms) {
  z = ordered_rows(
    raw[raw$specification == "monthly" & raw$term == term, ],
    "outcome",
    ys
  )
  
  label = if (startsWith(term, "w_")) {
    paste0("$W$ $\\times$ ", coef_names[sub("^w_", "", term)])
  } else {
    coef_names[term]
  }
  
  lines = c(
    lines,
    row(label, coef_star(z$estimate, z$p)),
    row("", se_text(z$se)),
    "\\addlinespace[1pt]"
  )
}

writeLines(
  c(lines, "\\end{longtable}"),
  "result/Table S4.tex"
)

output = subset(raw, specification == "monthly")
save_csv(add_sig_columns(output), "Table S4")


#################################################
# Table S5. Residual Diagnostics: no significance stars
#################################################
lines = c(
  "\\begin{tabular}{lrrrr}",
  "\\toprule",
  row(
    "Outcome", "Lag-1 median", "Lag-1 IQR",
    "Lag-12 median", "Moran's $I$ median"
  ),
  "\\midrule"
)

for (y in ys) {
  z = diagnostics[diagnostics$outcome == y, ]
  stopifnot(nrow(z) == 1)
  
  lines = c(
    lines,
    row(
      tex_y[y],
      num(z$ar1_median),
      paste0("[", num(z$ar1_q25), ", ", num(z$ar1_q75), "]"),
      num(z$ar12_median),
      num(z$moran_median)
    )
  )
}

save_tex(lines, "Table S5", 5)
save_csv(diagnostics, "Table S5")


#################################################
# Table S6. Compare Covariance Estimators
#################################################
# Stars on TEX estimates are based on HAC(12) p-values.

covariance_order = c("Joint_OIM", "HAC6", "HAC12", "HAC24")

lines = c(
  "\\begin{tabular}{lrrrrrr}",
  "\\toprule",
  row(
    "Outcome", "Estimate", "OIM SE",
    "HAC(6) SE", "HAC(12) SE", "HAC(24) SE",
    "HAC(12) 95\\% CI"
  ),
  "\\midrule"
)

for (y in ys) {
  z = inference[
    inference$specification == "monthly" &
      inference$outcome == y &
      inference$component == "Total" &
      inference$covariance %in% covariance_order,
  ]
  
  z = ordered_rows(z, "covariance", covariance_order)
  h = z[z$covariance == "HAC12", ]
  
  lines = c(
    lines,
    row(
      tex_y[y],
      coef_star(h$estimate, h$p),
      num(z$se),
      paste0("[", num(h$low), ", ", num(h$high), "]")
    )
  )
}

save_tex(
  lines, "Table S6", 7,
  notes = "Stars on estimates are based on HAC(12) p-values.",
  significance = TRUE
)

output = subset(
  inference,
  specification == "monthly" & component == "Total"
)

save_csv(add_sig_columns(output), "Table S6")