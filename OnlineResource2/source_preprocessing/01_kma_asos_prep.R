# 원본 XLSX에서 추출한 일자료와 좌표 이력을 읽습니다.
# CSV 추출본은 원자료 값을 보존하며, 강수 빈칸을 0으로 바꾸지 않습니다.
days = read_data("kma_raw_selected.csv.gz")
days$tm = as.Date(days$tm)
days = days[format(days$tm, "%Y") >= "2012" & format(days$tm, "%Y") <= "2024", ]
stopifnot(!anyDuplicated(days[c("stnId", "tm")]))
history = read_data("kma_coordinate_history.csv")
history$시작일 = as.Date(history$시작일)
history$종료일 = as.Date(history$종료일)
joined = merge(days, history, by.x = "stnId", by.y = "지점", all.x = TRUE)
keep = !is.na(joined$시작일) & joined$tm >= joined$시작일 &
  (is.na(joined$종료일) | joined$tm < joined$종료일)
days = joined[which(keep), ]
stopifnot(!anyDuplicated(days[c("stnId", "tm")]))
# 홍성 일괄 제외를 하지 않습니다. 이전 이력을 날짜로 적용합니다.
days$sumSsHr[is.finite(days$sumSsHr) & (days$sumSsHr < 0 | days$sumSsHr > 24)] = NA_real_
days$year = as.integer(format(days$tm, "%Y"))
days$month = as.integer(format(days$tm, "%m"))
groups = split(seq_len(nrow(days)), paste(days$stnId, days$year, days$month, sep = "_"))
var_map = c(avg_temp = "avgTa", avg_wind = "avgWs", avg_humid = "avgRhm", sun_time = "sumSsHr")
monthly = lapply(groups, function(ii) {
  d = days[ii, ]; first = as.Date(sprintf("%04d-%02d-01", d$year[1], d$month[1]))
  nd = as.integer(as.Date(format(first + 32, "%Y-%m-01")) - first)
  loc = unique(d[c("경도", "위도")])
  z = data.frame(station_id = d$stnId[1], year = d$year[1], month = d$month[1],
    longitude = loc$경도[1], latitude = loc$위도[1], calendar_days = nd,
    n_days = length(unique(d$tm)), coordinate_segments = nrow(loc))
  for (v in names(var_map)) {
    x = d[[var_map[[v]]]]; ok = is.finite(x)
    z[[v]] = if (sum(ok) / nd >= .75) mean(x[ok]) else NA_real_
  }
  wind_ok = is.finite(d$avgWs)
  z$stagnant_days = if (sum(wind_ok) / nd >= .75) mean(d$avgWs[wind_ok] <= 2) * nd else NA_real_
  z$raw_rain_sum = if (any(is.finite(d$sumRn))) sum(d$sumRn, na.rm = TRUE) else NA_real_
  z
})
kma_month = do.call(rbind, monthly)
rain = read_data("rain_official_comparison.csv")
kma_month = merge(kma_month, rain[c("stnId", "year", "month", "official_month_total")],
  by.x = c("station_id", "year", "month"), by.y = c("stnId", "year", "month"), all.x = TRUE)
rain_ok = is.finite(kma_month$official_month_total) & is.finite(kma_month$raw_rain_sum) &
  abs(kma_month$official_month_total - kma_month$raw_rain_sum) <= .051 &
  kma_month$n_days == kma_month$calendar_days
kma_month$avg_rain = ifelse(rain_ok, kma_month$official_month_total / kma_month$calendar_days, NA_real_)
# 이전월의 여러 좌표를 각각 완전한 관측소 월처럼 사용하지 않습니다.
valid_loc = kma_month$coordinate_segments == 1 &
  kma_month$longitude >= 124 & kma_month$longitude <= 132 &
  kma_month$latitude >= 32 & kma_month$latitude <= 40
kma_month = kma_month[which(valid_loc), ]
kma_input = do.call(rbind, lapply(c(names(var_map), "stagnant_days", "avg_rain"), function(v) {
  z = kma_month[is.finite(kma_month[[v]]), c("station_id", "year", "month", "longitude", "latitude", v)]
  names(z)[ncol(z)] = "value"; z$variable = v; z
}))
save_data(kma_month, "kma_station_month.csv")
