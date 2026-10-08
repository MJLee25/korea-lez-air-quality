#################################################
# 01. Prepare Analysis Data
#################################################
# Run after setting the working directory to the repository root.
# Outputs: Analysis panel, descriptive statistics, policy cohorts

##### Packages
library(dplyr)
library(tidyr)

dir.create("result", showWarnings = FALSE)

dir.create("result/_intermediate", showWarnings = FALSE)


#################################################
# Load Final Cleaned Data and Nearest-Station Data
#################################################

raw_data = read.csv("data/02_final_data.csv", fileEncoding = "UTF-8-BOM", check.names = FALSE)

nearest_data = read.csv("data/nearest_panel.csv", fileEncoding = "UTF-8-BOM", check.names = FALSE)


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
# Policy Adoption Areas and Timing
#################################################
gg18 = c(
  "김포시", "고양시 덕양구", "고양시 일산동구", "고양시 일산서구",
  "양주시", "의정부시", "남양주시", "구리시", "하남시", "성남시 분당구",
  "성남시 수정구", "성남시 중원구", "과천시", "안양시 동안구",
  "안양시 만안구", "의왕시", "수원시 권선구", "수원시 영통구",
  "수원시 장안구", "수원시 팔달구", "군포시", "시흥시", "광명시",
  "안산시 단원구", "안산시 상록구", "부천시"
)

gg20 = c(
  "파주시", "동두천시", "포천시", "광주시", "이천시", "용인시 기흥구",
  "용인시 수지구", "용인시 처인구", "여주시", "안성시", "오산시",
  "평택시", "화성시"
)

normalize_province = function(x) {
  x[x == "강원특별자치도"] = "강원도"
  x[x == "전북특별자치도"] = "전라북도"
  x
}


#################################################
# Construct the Analysis Panel
#################################################
load_panel = function(name) {
  data = if (name == "nearest") {
    nearest_data
  } else {
    raw_data
  }
  if (name == "dat13_24") {
    data = data[data$year >= 2013, ]
  }
  stopifnot(all(data$year >= 2012 & data$year <= 2024))
  names(data)[1:6] = c("id", "year", "month", "province", "district", "large_district")
  data = data %>% dplyr::select(-any_of("road_paving_rate"))
  for (y in outcomes) {
    names(data)[names(data) == paste0(y, "_도시대기")] = y
    names(data)[names(data) == paste0(y, "_도로변대기")] = paste0(y, "_road")
  }
  data = data %>%
    filter(!district %in% c("옹진군", "울릉군")) %>%
    mutate(
      province = normalize_province(province),
      time = as.double((year - 2012) * 12 + month),
      g = case_when(
        province == "서울특별시" ~ 61,
        province == "인천광역시" ~ 79,
        province == "경기도" & district %in% gg18 ~ 79,
        province == "경기도" & district %in% gg20 ~ 97,
        TRUE ~ 0
      ),
      cohort = g,
      lez = as.numeric(g > 0 & time >= g),
      season = case_when(
        month %in% c(12, 1, 2) ~ "Winter",
        month %in% 3:5 ~ "Spring",
        month %in% 6:8 ~ "Summer",
        TRUE ~ "Autumn"
      )
    ) %>%
    arrange(id, time)
  stopifnot(
    !anyDuplicated(data[c("id", "time")]), n_distinct(data$id) == 247,
    identical(as.integer(table(distinct(data, id, g)$g)), c(
      174L, 25L, 35L,
      13L
    ))
  )
  data
}


#################################################
# Define Analysis Periods
#################################################
panel_names = c("dat12_24", "dat13_24")

panels = lapply(panel_names, load_panel)

names(panels) = panel_names

data = panels$dat12_24
head(data)

#################################################
# Check Data
#################################################
audit = bind_rows(lapply(names(panels), function(nm) {
  z = panels[[nm]]
  data.frame(
    dataset = nm, first_year = min(z$year), last_year = max(z$year),
    units = n_distinct(z$id), months = n_distinct(z$time), observations = nrow(z),
    missing = sum(is.na(z)), controls = paste(intersect(full, names(z)), collapse = "; ")
  )
}))

write.csv(audit, "result/_intermediate/data_audit.csv", row.names = FALSE)

overlap = bind_rows(lapply(setdiff(names(panels), "dat12_24"), function(nm) {
  z = panels[[nm]]
  both = merge(data, z, by = c("id", "time"), suffixes = c(".a", ".b"))
  vars = intersect(c(full, outcomes, paste0(outcomes, "_road")), names(z))
  bind_rows(lapply(vars, function(v) {
    delta = both[[paste0(v, ".a")]] - both[[paste0(v, ".b")]]
    data.frame(dataset = nm, variable = v, shared_rows = nrow(both), changed = sum(abs(delta) >
      1e-06), max_abs_difference = max(abs(delta)))
  }))
}))

write.csv(overlap, "result/_intermediate/overlap_audit.csv", row.names = FALSE)


#################################################
# Check Annual Covariates
#################################################
annual_replication = bind_rows(lapply(full, function(v) {
  q = data %>%
    group_by(id, year) %>%
    summarise(
      nvalues = n_distinct(.data[[v]]),
      .groups = "drop"
    )
  data.frame(variable = v, unit_years = nrow(q), constant_within_year = sum(q$nvalues ==
    1))
}))

write.csv(annual_replication, "result/_intermediate/within_year_variation.csv",
  row.names = FALSE
)

write.csv(distinct(data, id, province, district, g), "result/_intermediate/cohort_membership.csv",
  row.names = FALSE, fileEncoding = "UTF-8"
)

write.csv(bind_rows(lapply(outcomes, function(y) {
  pre = data$g > 0 & data$time < data$g
  data.frame(
    outcome = y, mean = mean(data[[y]]), sd = sd(data[[y]]), min = min(data[[y]]),
    max = max(data[[y]]), treated_pre_mean = mean(data[[y]][pre]), pre_observations = sum(pre)
  )
})), "result/_intermediate/summary_statistics.csv", row.names = FALSE)  # = Table 1

nearest_panel = load_panel("nearest")

write.csv(data, "result/_intermediate/analysis_panel.csv", row.names = FALSE, fileEncoding = "UTF-8")

write.csv(nearest_panel, "result/_intermediate/nearest_analysis_panel.csv",
  row.names = FALSE,
  fileEncoding = "UTF-8"
)
