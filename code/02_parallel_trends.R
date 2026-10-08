#################################################
# 02. Parallel Trends Analysis
#################################################

# Run after setting the working directory to the repository root.
# Outputs: event_dynamic.csv, event_summary.csv, event_group_time.csv

##### Packages
library(dplyr)
library(did)


#################################################
# Load Analysis Data
#################################################
data = read.csv("result/_intermediate/analysis_panel.csv",
  fileEncoding = "UTF-8",
  check.names = FALSE
)
head(data)

# Use double precision to retain the never-treated group in did.
data$time = as.double(data$time)
data$g = as.double(data$g)


#################################################
# Outcome Variables and Adjustment Covariates
#################################################
outcomes = c("NO2", "CO", "SO2", "O3", "PM10")

weather = c("avg_temp", "sun_time", "stagnant_days", "avg_wind", "avg_humid", "avg_rain")

core = c("pop_density", "daily_km", "cars_per_capita", weather)

full = c(
  "pop_density", "industrial_area", "commercial_area", "green_area_per_capita",
  "daily_km", "cars_per_capita", weather
)

panels = list(dat12_24 = data, dat13_24 = data[data$year >= 2013, ])


#################################################
# Group-Time Estimation and Pre-Trend Tests
################################################
run_event = function(nm, method, control_vars) {
  z = panels[[nm]] %>% dplyr::select(id, time, g, all_of(outcomes), all_of(control_vars))
  stopifnot(!anyNA(z))
  for (v in control_vars) {
    z[[v]] = as.numeric(scale(z[[v]]))
  }
  results = lapply(outcomes, function(y) {
    message("EVENT ", nm, " ", method, " ", y)
    set.seed(20260907)
    m = att_gt(
      yname = y,
      tname = "time",
      idname = "id",
      gname = "g",
      data = z,
      control_group = "notyettreated",
      base_period = "universal",
      est_method = method,
      xformla = reformulate(control_vars),
      bstrap = TRUE,
      cband = TRUE,
      biters = 1999,
      print_details = FALSE
    )
    stopifnot(m$n == n_distinct(z$id))
    # Maximum |t| statistic for the pre-treatment period
    pre = which(m$t < m$group - 1 & is.finite(m$att) & m$se > 0)
    V = as.matrix(m$V_analytical)[pre, pre, drop = FALSE]
    iff = as.matrix(m$inffunc)[, pre, drop = FALSE]
    analytic_se = sqrt(colMeans(iff^2) / m$n)
    observed = max(abs(m$att[pre] / analytic_se))
    set.seed(20260907)
    multipliers = matrix(sample(c(-1, 1), m$n * 1999, replace = TRUE), nrow = m$n)
    boot = crossprod(iff, multipliers) / m$n / analytic_se
    max_t_p = (1 + sum(apply(abs(boot), 2, max) >= observed)) / 2000
    w = if (length(m$W) == 1) {
      as.numeric(m$W)
    } else {
      NA_real_
    }
    wp = if (is.finite(w)) {
      pchisq(w, length(pre), lower.tail = FALSE)
    } else {
      NA_real_
    }
    # Event-time range for the manuscript figures
    a = aggte(m, type = "dynamic", min_e = -48, max_e = 60, na.rm = TRUE)
    list(summary = data.frame(
      dataset = nm, estimator = method, outcome = y,
      units = m$n, observations = nrow(z), pre_restrictions = length(pre),
      covariance_rank = qr(V)$rank, covariance_rcond = rcond(V), wald = w,
      wald_p = wp, max_t = observed, max_t_p = max_t_p
    ), dynamic = data.frame(
      dataset = nm,
      estimator = method, outcome = y, event_month = a$egt, estimate = a$att.egt,
      se = a$se.egt, low = a$att.egt - a$crit.val.egt * a$se.egt, high = a$att.egt +
        a$crit.val.egt * a$se.egt
    ), group_time = data.frame(
      dataset = nm,
      estimator = method, outcome = y, group = m$group, time = m$t, estimate = m$att,
      se = m$se
    ))
  })
  ans = lapply(c("summary", "dynamic", "group_time"), function(key) {
    bind_rows(lapply(results, `[[`, key))
  })
  names(ans) = c("summary", "dynamic", "group_time")
  ans
}


#################################################
# Regression Adjustment and Doubly Robust Estimation for Both Analysis Periods
#################################################
events = list()

for (nm in names(panels)) {
  for (method in c("reg", "dr")) {
    controls = full
    events[[paste(nm, method)]] = run_event(nm, method, controls)
  }
}

##### Save Results
for (key in c("summary", "dynamic", "group_time")) {
  output = bind_rows(lapply(events, `[[`, key))
  file = paste0("result/_intermediate/event_", key, ".csv")
  write.csv(output, file, row.names = FALSE)
}


## event_summary.csv    : Pre-trend test summary and data for Table S1
## event_group_time.csv : Estimates and standard errors by policy adoption cohort and calendar period
## event_dynamic.csv    : Aggregated event-time estimates and confidence intervals for plotting


