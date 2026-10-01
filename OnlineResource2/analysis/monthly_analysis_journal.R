# Journal workflow: revised separately from the preserved earlier script.
suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(sf)
  library(spdep)
  library(splm)
  library(plm)
  library(did)
  library(ggplot2)
})

arg <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
project <- normalizePath(Sys.getenv("LEZ_PROJECT_ROOT", unset = file.path(dirname(arg), "../../../..")))
paper <- normalizePath(file.path(dirname(arg), ".."))
out <- file.path(paper, "monthly_results")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
mode <- commandArgs(trailingOnly = TRUE)
if (!length(mode)) mode <- "all"
if (!is.null(getOption("lez.analysis.mode"))) mode <- getOption("lez.analysis.mode")
set.seed(20260907)
write_csv <- function(x, name) write.csv(x, file.path(out, paste0(name, ".csv")), row.names = FALSE, na = "NA")
bundled_input <- file.path(paper, "inputs", "02_final_data.csv")
input_dir <- Sys.getenv("LEZ_DATA_DIR", unset = if (file.exists(bundled_input)) file.path(paper, "inputs") else file.path(project, "코드및데이터"))
files <- list.files(input_dir, recursive = TRUE, full.names = TRUE)
find_file <- function(name) {
  x <- files[basename(files) == name]
  if (length(x) != 1L) stop("Nonunique file: ", name)
  x
}
primary_input <- find_file("02_final_data.csv")
nearest_input <- file.path(paper, "inputs", "nearest_panel.csv")
coordinate_input <- file.path(input_dir, "analysis_coordinates.csv")
geometry_input <- if (file.exists(coordinate_input)) coordinate_input else find_file("full_1920_d.geojson")
input_paths <- c(primary_input, geometry_input)
if (file.exists(nearest_input)) input_paths <- c(input_paths, nearest_input)
analysis_signature <- paste(tools::md5sum(c(file.path(dirname(arg), "monthly_analysis_journal.R"), input_paths)), collapse = "|")
write.csv(data.frame(file = input_paths, md5 = unname(tools::md5sum(input_paths))),
  file.path(out, "input_checksums.csv"), row.names = FALSE)
outcomes <- c("NO2", "CO", "SO2", "O3", "PM10")
weather <- c("avg_temp", "sun_time", "stagnant_days", "avg_wind", "avg_humid", "avg_rain")
core <- c("pop_density", "daily_km", "cars_per_capita", weather)
full <- c("pop_density", "industrial_area", "commercial_area", "green_area_per_capita", "daily_km", "cars_per_capita", weather)
gg18 <- c("김포시", "고양시 덕양구", "고양시 일산동구", "고양시 일산서구", "양주시", "의정부시", "남양주시", "구리시", "하남시", "성남시 분당구", "성남시 수정구", "성남시 중원구", "과천시", "안양시 동안구", "안양시 만안구", "의왕시", "수원시 권선구", "수원시 영통구", "수원시 장안구", "수원시 팔달구", "군포시", "시흥시", "광명시", "안산시 단원구", "안산시 상록구", "부천시")
gg20 <- c("파주시", "동두천시", "포천시", "광주시", "이천시", "용인시 기흥구", "용인시 수지구", "용인시 처인구", "여주시", "안성시", "오산시", "평택시", "화성시")
normalize_province <- function(x) {
  x[x == "강원특별자치도"] <- "강원도"
  x[x == "전북특별자치도"] <- "전라북도"
  x
}
load_panel <- function(name) {
  d <- read.csv(if (name == "nearest") nearest_input else primary_input,
    fileEncoding = "UTF-8-BOM", check.names = FALSE)
  if (name == "dat13_24") d <- d[d$year >= 2013, ]
  stopifnot(all(d$year >= 2012 & d$year <= 2024))
  names(d)[1:6] <- c("id", "year", "month", "province", "district", "large_district")
  d <- d %>% dplyr::select(-any_of("road_paving_rate"))
  for (y in outcomes) {
    names(d)[names(d) == paste0(y, "_도시대기")] <- y
    names(d)[names(d) == paste0(y, "_도로변대기")] <- paste0(y, "_road")
  }
  d <- d %>% filter(!district %in% c("옹진군", "울릉군")) %>%
    mutate(province = normalize_province(province),
      time = as.double((year - 2012) * 12 + month),
      g = case_when(province == "서울특별시" ~ 61,
        province == "인천광역시" ~ 79,
        province == "경기도" & district %in% gg18 ~ 79,
        province == "경기도" & district %in% gg20 ~ 97, TRUE ~ 0),
      cohort = g,
      lez = as.numeric(g > 0 & time >= g),
      season = case_when(month %in% c(12, 1, 2) ~ "Winter", month %in% 3:5 ~ "Spring",
        month %in% 6:8 ~ "Summer", TRUE ~ "Autumn")) %>% arrange(id, time)
  stopifnot(!anyDuplicated(d[c("id", "time")]), n_distinct(d$id) == 247,
    identical(as.integer(table(distinct(d, id, g)$g)), c(174L, 25L, 35L, 13L)))
  d
}
panel_names <- c("dat12_24", "dat13_24")
if (Sys.getenv("LEZ_INCLUDE_2025") == "1") panel_names <- c(panel_names, "dat12_25")
panels <- lapply(panel_names, load_panel)
names(panels) <- panel_names
d <- panels$dat12_24
nearest_panel <- if (file.exists(nearest_input)) load_panel("nearest") else NULL

audit <- bind_rows(lapply(names(panels), function(nm) {
  z <- panels[[nm]]
  data.frame(dataset = nm, first_year = min(z$year), last_year = max(z$year),
    units = n_distinct(z$id), months = n_distinct(z$time), observations = nrow(z),
    missing = sum(is.na(z)), controls = paste(intersect(full, names(z)), collapse = "; "))
}))
write_csv(audit, "data_audit")
overlap <- bind_rows(lapply(setdiff(names(panels), "dat12_24"), function(nm) {
  z <- panels[[nm]]; both <- merge(d, z, by = c("id", "time"), suffixes = c(".a", ".b"))
  vars <- intersect(c(full, outcomes, paste0(outcomes, "_road")), names(z))
  bind_rows(lapply(vars, function(v) {
    delta <- both[[paste0(v, ".a")]] - both[[paste0(v, ".b")]]
    data.frame(dataset = nm, variable = v, shared_rows = nrow(both),
      changed = sum(abs(delta) > 1e-6), max_abs_difference = max(abs(delta)))
  }))
}))
write_csv(overlap, "overlap_audit")
annual_replication <- bind_rows(lapply(full, function(v) {
  q <- d %>% group_by(id, year) %>% summarise(nvalues = n_distinct(.data[[v]]), .groups = "drop")
  data.frame(variable = v, unit_years = nrow(q), constant_within_year = sum(q$nvalues == 1))
}))
write_csv(annual_replication, "within_year_variation")
write_csv(distinct(d, id, province, district, g), "cohort_membership")
write_csv(bind_rows(lapply(outcomes, function(y) {
  pre <- d$g > 0 & d$time < d$g
  data.frame(outcome = y, mean = mean(d[[y]]), sd = sd(d[[y]]), min = min(d[[y]]), max = max(d[[y]]),
    treated_pre_mean = mean(d[[y]][pre]), pre_observations = sum(pre))
})), "summary_statistics")
if (mode == "audit") quit(save = "no")

if (file.exists(coordinate_input)) {
  coordinates <- read.csv(coordinate_input)
  stopifnot(identical(coordinates$id, sort(unique(d$id))), !anyNA(coordinates),
    all(coordinates$epsg == 5179L))
  coords <- as.matrix(coordinates[c("x", "y")])
  rownames(coords) <- coordinates$id
} else {
geo <- geojsonsf::geojson_sf(geometry_input)
names(geo)[24:25] <- c("province", "district")
geo <- geo %>% filter(year == 2019) %>% mutate(province = normalize_province(province)) %>%
  dplyr::select(province, district, geometry)
units <- distinct(d, id, province, district)
units$province[units$district == "군위군"] <- "대구광역시"
geo <- left_join(units, geo, by = c("province", "district")) %>% st_as_sf() %>% arrange(id)
if (any(st_is_empty(geo))) print(st_drop_geometry(geo[st_is_empty(geo), ]))
stopifnot(nrow(geo) == 247, !any(st_is_empty(geo)), !any(is.na(st_dimension(geo))))
coords <- st_coordinates(st_centroid(st_geometry(st_transform(geo, 5179)), of_largest_polygon = TRUE))
rownames(coords) <- geo$id
write.csv(data.frame(id = geo$id, x = coords[, 1], y = coords[, 2], epsg = 5179L),
  file.path(out, "analysis_coordinates.csv"), row.names = FALSE)
}
make_w <- function(ids, k = 5) {
  xy <- coords[as.character(sort(ids)), , drop = FALSE]
  nb2listw(knn2nb(knearneigh(xy, k = k)), style = "W")
}
add_w <- function(z, listw, vars) {
  z <- z %>% arrange(id, time)
  ids <- sort(unique(z$id))
  for (tt in sort(unique(z$time))) {
    ix <- which(z$time == tt)
    stopifnot(identical(z$id[ix], ids))
    for (v in vars) z[ix, paste0("w_", v)] <- as.numeric(lag.listw(listw, z[[v]][ix]))
  }
  z
}

# Preliminary output uses the covariance exposed by splm. Final manuscript
# inference reconstructs joint information and score HAC in monthly_inference_journal.R.
impact <- function(fit, listw, var = "lez") {
  b <- coef(fit); V <- vcov(fit); ev <- eigen(listw2mat(listw), only.values = TRUE)$values
  rho <- b["lambda"]; beta <- b[var]; theta <- b[paste0("w_", var)]
  direct <- Re(mean((beta + theta * ev) / (1 - rho * ev)))
  total <- (beta + theta) / (1 - rho)
  gd <- gt <- setNames(rep(0, length(b)), names(b))
  gd["lambda"] <- Re(mean((beta + theta * ev) * ev / (1 - rho * ev)^2))
  gd[var] <- Re(mean(1 / (1 - rho * ev)))
  gd[paste0("w_", var)] <- Re(mean(ev / (1 - rho * ev)))
  gt["lambda"] <- (beta + theta) / (1 - rho)^2
  gt[c(var, paste0("w_", var))] <- 1 / (1 - rho)
  J <- rbind(gd, gt - gd, gt)
  se <- sqrt(diag(J %*% V %*% t(J)))
  est <- c(direct, total - direct, total)
  data.frame(component = c("Direct", "Indirect", "Total"), estimate = as.numeric(est),
    se = se, low = est - 1.96 * se, high = est + 1.96 * se,
    p = 2 * pnorm(abs(est / se), lower.tail = FALSE), rho = unname(rho))
}

fit_spec <- function(name, z = d, controls = full, k = 5, trend = FALSE, ys = outcomes) {
  path <- file.path(out, paste0("fit_", name, ".rds"))
  if (file.exists(path)) {
    cached <- readRDS(path)
    if (identical(cached$signature, analysis_signature)) return(cached)
  }
  listw <- make_w(unique(z$id), k)
  for (v in controls) z[[v]] <- as.numeric(scale(z[[v]]))
  if (trend) {
    for (g0 in c(61, 79, 97)) z[[paste0("trend", g0)]] <- as.numeric(z$cohort == g0) * (z$time - 60) / 12
    controls <- c(controls, paste0("trend", c(61, 79, 97)))
  }
  z <- add_w(z, listw, c("lez", controls))
  rhs <- c("lez", controls, "w_lez", paste0("w_", controls))
  ans <- lapply(ys, function(y) {
    message("SDM ", name, " ", y, " (", nrow(z), " observations)")
    fit <- spml(reformulate(rhs, y), data = as.data.frame(z), listw = listw,
      index = c("id", "time"), model = "within", effect = "twoways", lag = TRUE, spatial.error = "none")
    imp <- impact(fit, listw)
    pre <- z$g > 0 & z$time < z$g
    ref <- mean(z[[y]][pre])
    imp <- cbind(specification = name, outcome = y, n = nrow(z), units = n_distinct(z$id),
      periods = n_distinct(z$time), imp, pre_mean = ref, relative_percent = 100 * imp$estimate / ref)
    b <- coef(fit); se <- sqrt(diag(vcov(fit)))
    raw <- data.frame(specification = name, outcome = y, term = names(b),
      estimate = as.numeric(b), se = se, p = 2 * pnorm(abs(b / se), lower.tail = FALSE))
    # A unit-clustered non-spatial benchmark makes repeated-month inference explicit.
    tw <- plm(reformulate(c("lez", controls), y), data = z, index = c("id", "time"), model = "within", effect = "twoways")
    tse <- sqrt(vcovHC(tw, method = "arellano", type = "HC1", cluster = "group")["lez", "lez"])
    list(impact = imp, raw = raw, twfe = data.frame(specification = name, outcome = y,
      estimate = unname(coef(tw)["lez"]), se = tse, p = 2 * pnorm(abs(coef(tw)["lez"] / tse), lower.tail = FALSE)))
  })
  ans <- list(signature = analysis_signature, impacts = bind_rows(lapply(ans, `[[`, "impact")), raw = bind_rows(lapply(ans, `[[`, "raw")), twfe = bind_rows(lapply(ans, `[[`, "twfe")))
  saveRDS(ans, path)
  ans
}

if (mode %in% c("all", "models", "probe")) {
  specs <- list(monthly = fit_spec(if (mode == "probe") "probe" else "monthly", ys = if (mode == "probe") "NO2" else outcomes))
  if (mode == "probe") {print(specs$monthly$impacts); quit(save = "no")}
  for (s in c("Winter", "Spring", "Summer", "Autumn")) specs[[s]] <- fit_spec(s, d %>% filter(season == s))
  for (s in c("Winter", "Spring", "Summer", "Autumn")) {
    specs[[paste0("trend_", s)]] <- fit_spec(paste0("trend_", s), d %>% filter(season == s), trend = TRUE)
  }
  specs$may_june <- fit_spec("may_june", d %>% filter(month %in% 5:6), ys = "O3")
  specs$trends <- fit_spec("trends", trend = TRUE)
  specs$no_transport <- fit_spec("no_transport", controls = setdiff(full, c("daily_km", "cars_per_capita")))
  specs$k3 <- fit_spec("k3", k = 3)
  specs$k7 <- fit_spec("k7", k = 7)
  for (g0 in c(61, 79, 97)) specs[[paste0("omit", g0)]] <- fit_spec(paste0("omit", g0), d %>% filter(g != g0))
  specs$start2013 <- fit_spec("start2013", d %>% filter(year >= 2013))
  specs$core2024 <- fit_spec("core2024", controls = core)
  if ("dat12_25" %in% names(panels)) specs$core2025 <- fit_spec("core2025", panels$dat12_25, controls = core)
  early <- d; early$g[early$g == 79] <- 73; early$lez <- as.numeric(early$g > 0 & early$time >= early$g)
  specs$jan2018 <- fit_spec("jan2018", early)
  specs$jan2018_trends <- fit_spec("jan2018_trends", early, trend = TRUE)
  # Timing scenarios change designation, not the membership of cohort trends.
  for (month in c(7, 12)) {
    shifted <- d
    shifted$g[shifted$cohort == 97] <- 96 + month
    shifted$lez <- as.numeric(shifted$g > 0 & shifted$time >= shifted$g)
    label <- if (month == 7) "jul2020" else "dec2020"
    specs[[label]] <- fit_spec(label, shifted)
    specs[[paste0(label, "_trends")]] <- fit_spec(paste0(label, "_trends"), shifted, trend = TRUE)
  }
  stopifnot(!is.null(nearest_panel))
  specs$nearest <- fit_spec("nearest", nearest_panel)
  specs$nearest_trends <- fit_spec("nearest_trends", nearest_panel, trend = TRUE)
  for (key in c("impacts", "raw", "twfe")) write_csv(bind_rows(lapply(specs, `[[`, key)), paste0("sdm_", key))
}

run_event <- function(nm, method, control_vars) {
  path <- file.path(out, paste0("event_", nm, "_", method, ".rds"))
  if (file.exists(path)) {
    cached <- readRDS(path)
    if (identical(attr(cached, "signature"), analysis_signature)) return(cached)
  }
  z <- panels[[nm]] %>% dplyr::select(id, time, g, all_of(outcomes), all_of(control_vars))
  stopifnot(!anyNA(z))
  for (v in control_vars) z[[v]] <- as.numeric(scale(z[[v]]))
  results <- lapply(outcomes, function(y) {
    message("EVENT ", nm, " ", method, " ", y)
    set.seed(20260907)
    m <- att_gt(yname = y, tname = "time", idname = "id", gname = "g", data = z,
      control_group = "notyettreated", base_period = "universal", est_method = method,
      xformla = reformulate(control_vars), bstrap = TRUE, cband = TRUE, biters = 1999,
      print_details = FALSE)
    pre <- which(m$t < m$group - 1 & is.finite(m$att) & m$se > 0)
    V <- as.matrix(m$V_analytical)[pre, pre, drop = FALSE]
    iff <- as.matrix(m$inffunc)[, pre, drop = FALSE]
    analytic_se <- sqrt(colMeans(iff^2) / m$n)
    observed <- max(abs(m$att[pre] / analytic_se))
    set.seed(20260907)
    multipliers <- matrix(sample(c(-1, 1), m$n * 1999, replace = TRUE), nrow = m$n)
    boot <- crossprod(iff, multipliers) / m$n / analytic_se
    max_t_p <- (1 + sum(apply(abs(boot), 2, max) >= observed)) / 2000
    w <- if (length(m$W) == 1) as.numeric(m$W) else NA_real_
    wp <- if (is.finite(w)) pchisq(w, length(pre), lower.tail = FALSE) else NA_real_
    a <- aggte(m, type = "dynamic", min_e = -48, max_e = 60, na.rm = TRUE)
    list(summary = data.frame(dataset = nm, estimator = method, outcome = y,
      units = m$n, observations = nrow(z), pre_restrictions = length(pre), covariance_rank = qr(V)$rank,
      covariance_rcond = rcond(V), wald = w, wald_p = wp, max_t = observed, max_t_p = max_t_p),
      dynamic = data.frame(dataset = nm, estimator = method, outcome = y, event_month = a$egt,
        estimate = a$att.egt, se = a$se.egt, low = a$att.egt - a$crit.val.egt * a$se.egt,
        high = a$att.egt + a$crit.val.egt * a$se.egt),
      group_time = data.frame(dataset = nm, estimator = method, outcome = y, group = m$group,
        time = m$t, estimate = m$att, se = m$se))
  })
  ans <- lapply(c("summary", "dynamic", "group_time"), function(key) bind_rows(lapply(results, `[[`, key)))
  names(ans) <- c("summary", "dynamic", "group_time")
  attr(ans, "signature") <- analysis_signature
  saveRDS(ans, path)
  ans
}
if (mode %in% c("all", "events")) {
  events <- list()
  for (nm in names(panels)) for (method in c("reg", "dr")) {
    controls <- if (nm == "dat12_25") core else full
    events[[paste(nm, method)]] <- run_event(nm, method, controls)
  }
  for (key in c("summary", "dynamic", "group_time")) write_csv(bind_rows(lapply(events, `[[`, key)), paste0("event_", key))
}
capture.output(sessionInfo(), file = file.path(out, "sessionInfo.txt"))
