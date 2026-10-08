#################################################
# 03. Spatial Models and Sensitivity Analysis
#################################################

# Run after setting the working directory to the repository root.
# Outputs: sdm_impacts.csv, sdm_raw.csv, sdm_twfe.csv

##### Packages
library(dplyr)
library(spdep)
library(splm)
library(plm)


#################################################
# Load Analysis Data
#################################################

data = read.csv("result/_intermediate/analysis_panel.csv",
  fileEncoding = "UTF-8",
  check.names = FALSE
)

nearest_panel = read.csv("result/_intermediate/nearest_analysis_panel.csv",
  fileEncoding = "UTF-8",
  check.names = FALSE
)


#################################################
# Outcome Variables and Covariates
#################################################
outcomes = c("NO2", "CO", "SO2", "O3", "PM10")

weather = c("avg_temp", "sun_time", "stagnant_days", "avg_wind", "avg_humid", "avg_rain")

core = c("pop_density", "daily_km", "cars_per_capita", weather)

full = c(
  "pop_density", "industrial_area", "commercial_area", "green_area_per_capita",
  "daily_km", "cars_per_capita", weather
)


#################################################
# Coordinates for the Spatial Weight Matrix
#################################################
coordinates = read.csv("data/analysis_coordinates.csv")

coords = as.matrix(coordinates[c("x", "y")])

rownames(coords) = coordinates$id


#################################################
# k-Nearest-Neighbor Spatial Weight Matrix
#################################################
make_w = function(ids, k = 5) {
  xy = coords[as.character(sort(ids)), , drop = FALSE]
  nb2listw(knn2nb(knearneigh(xy, k = k)), style = "W")
}


#################################################
# Generate Spatially Lagged Covariates
#################################################
add_w = function(z, listw, vars) {
  z = z %>% arrange(id, time)
  ids = sort(unique(z$id))
  for (tt in sort(unique(z$time))) {
    ix = which(z$time == tt)
    stopifnot(identical(z$id[ix], ids))
    for (v in vars) {
      z[ix, paste0("w_", v)] = as.numeric(lag.listw(listw, z[[v]][ix]))
    }
  }
  z
}


#################################################
# Calculate Direct, Indirect, and Total Effects
#################################################
impact = function(fit, listw, var = "lez") {
  b = coef(fit)
  V = vcov(fit)
  ev = eigen(listw2mat(listw), only.values = TRUE)$values
  rho = b["lambda"]
  beta = b[var]
  theta = b[paste0("w_", var)]
  direct = Re(mean((beta + theta * ev) / (1 - rho * ev)))
  total = (beta + theta) / (1 - rho)
  gd = gt = setNames(rep(0, length(b)), names(b))
  gd["lambda"] = Re(mean((beta + theta * ev) * ev / (1 - rho * ev)^2))
  gd[var] = Re(mean(1 / (1 - rho * ev)))
  gd[paste0("w_", var)] = Re(mean(ev / (1 - rho * ev)))
  gt["lambda"] = (beta + theta) / (1 - rho)^2
  gt[c(var, paste0("w_", var))] = 1 / (1 - rho)
  J = rbind(gd, gt - gd, gt)
  se = sqrt(diag(J %*% V %*% t(J)))
  est = c(direct, total - direct, total)
  data.frame(
    component = c("Direct", "Indirect", "Total"), estimate = as.numeric(est),
    se = se, low = est - 1.96 * se, high = est + 1.96 * se, p = 2 * pnorm(abs(est / se),
      lower.tail = FALSE
    ), rho = unname(rho)
  )
}


#################################################
# Spatial Models and Non-Spatial Benchmark Models
#################################################
fit_spec = function(name, z = data, controls = full, k = 5, trend = FALSE, ys = outcomes) {
  listw = make_w(unique(z$id), k)
  for (v in controls) {
    z[[v]] = as.numeric(scale(z[[v]]))
  }
  if (trend) {
    for (g0 in c(61, 79, 97)) {
      z[[paste0("trend", g0)]] = as.numeric(z$cohort == g0) * (z$time - 60) / 12
    }
    controls = c(controls, paste0("trend", c(61, 79, 97)))
  }
  z = add_w(z, listw, c("lez", controls))
  rhs = c("lez", controls, "w_lez", paste0("w_", controls))
  ans = lapply(ys, function(y) {
    message("SDM ", name, " ", y, " (", nrow(z), " observations)")
    fit = spml(
      formula = reformulate(rhs, y),
      data = as.data.frame(z),
      listw = listw,
      index = c("id", "time"),
      model = "within",
      effect = "twoways",
      lag = TRUE,
      spatial.error = "none"
    )
    imp = impact(fit, listw)
    pre = z$g > 0 & z$time < z$g
    ref = mean(z[[y]][pre])
    imp = cbind(
      specification = name, outcome = y, n = nrow(z), units = n_distinct(z$id),
      periods = n_distinct(z$time), imp, pre_mean = ref, relative_percent = 100 *
        imp$estimate / ref
    )
    b = coef(fit)
    se = sqrt(diag(vcov(fit)))
    raw = data.frame(
      specification = name, outcome = y, term = names(b), estimate = as.numeric(b),
      se = se, p = 2 * pnorm(abs(b / se), lower.tail = FALSE)
    )
    # Non-spatial benchmark model with district-clustered standard errors
    tw = plm(
      formula = reformulate(c("lez", controls), y),
      data = z,
      index = c("id", "time"),
      model = "within",
      effect = "twoways"
    )
    tw_covariance = vcovHC(tw, method = "arellano", type = "HC1", cluster = "group")
    tse = sqrt(tw_covariance["lez", "lez"])
    list(impact = imp, raw = raw, twfe = data.frame(
      specification = name, outcome = y,
      estimate = unname(coef(tw)["lez"]), se = tse, p = 2 * pnorm(abs(coef(tw)["lez"] / tse),
        lower.tail = FALSE
      )
    ))
  })
  ans = list(
    impacts = bind_rows(lapply(ans, `[[`, "impact")),
    raw = bind_rows(lapply(ans, `[[`, "raw")),
    twfe = bind_rows(lapply(ans, `[[`, "twfe"))
  )
  ans
}


#################################################
# Main and Seasonal Analyses
#################################################
specs = list(monthly = fit_spec("monthly"))

for (s in c("Winter", "Spring", "Summer", "Autumn")) {
  specs[[s]] = fit_spec(s, data %>% filter(season == s))
}

for (s in c("Winter", "Spring", "Summer", "Autumn")) {
  specs[[paste0("trend_", s)]] = fit_spec(paste0("trend_", s), data %>% filter(season ==
    s), trend = TRUE)
}


#################################################
# Sensitivity to Trends and Covariates
#################################################
specs$may_june = fit_spec("may_june", data %>% filter(month %in% 5:6), ys = "O3")

specs$trends = fit_spec("trends", trend = TRUE)

specs$no_transport = fit_spec("no_transport", controls = setdiff(full, c(
  "daily_km",
  "cars_per_capita"
)))


#################################################
# Sensitivity to the Number of Neighbors
#################################################
specs$k3 = fit_spec("k3", k = 3)

specs$k7 = fit_spec("k7", k = 7)

for (g0 in c(61, 79, 97)) {
  specs[[paste0("omit", g0)]] = fit_spec(paste0("omit", g0), data %>% filter(g !=
    g0))
}


#################################################
# Sensitivity to the Analysis Period and Covariate Set
#################################################
specs$start2013 = fit_spec("start2013", data %>% filter(year >= 2013))

specs$core2024 = fit_spec("core2024", controls = core)


#################################################
# Sensitivity to Policy Adoption Month
#################################################
early = data

early$g[early$g == 79] = 73

early$lez = as.numeric(early$g > 0 & early$time >= early$g)

specs$jan2018 = fit_spec("jan2018", early)

specs$jan2018_trends = fit_spec("jan2018_trends", early, trend = TRUE)

for (month in c(7, 12)) {
  shifted = data
  shifted$g[shifted$cohort == 97] = 96 + month
  shifted$lez = as.numeric(shifted$g > 0 & shifted$time >= shifted$g)
  label = if (month == 7) {
    "jul2020"
  } else {
    "dec2020"
  }
  specs[[label]] = fit_spec(label, shifted)
  specs[[paste0(label, "_trends")]] = fit_spec(paste0(label, "_trends"), shifted,
    trend = TRUE
  )
}

stopifnot(!is.null(nearest_panel))


#################################################
# Sensitivity to Interpolation Method
################################################# 
specs$nearest = fit_spec("nearest", nearest_panel)

specs$nearest_trends = fit_spec("nearest_trends", nearest_panel, trend = TRUE)

##### Save Results
for (key in c("impacts", "raw", "twfe")) {
  output = bind_rows(lapply(specs, `[[`, key))
  file = paste0("result/_intermediate/sdm_", key, ".csv")
  write.csv(output, file, row.names = FALSE)
}
