# 2012–2024 RDS에서 재집계·대조한 월자료입니다.
# 시간별 재집계 코드는 원자료재집계 폴더에 함께 보존합니다.
air = read_data("air_raw_month_with_metadata.csv.gz")
air$exact_name_match = tolower(as.character(air$exact_name_match)) == "true"
air$used_network = ifelse(is.na(air$network) | air$network == "", air$current_network, air$network)
air$longitude[air$station_code == 437551] = 128.2817
air$latitude[air$station_code == 437551] = 35.7262
keep = air$exact_name_match & air$n_duplicate_timestamp == 0 & air$coverage_calendar >= .75 &
  is.finite(air$mean_source_month) & air$longitude >= 124 & air$longitude <= 132 &
  air$latitude >= 32 & air$latitude <= 40 & air$used_network %in% c("도시대기", "도로변대기") &
  (air$station_code != 437551 | air$ym == 202009)
air = air[which(keep), ]
air_input = data.frame(station_id = air$station_code, year = air$year, month = air$month,
  longitude = air$longitude, latitude = air$latitude,
  value = air$mean_source_month * ifelse(air$pollutant == "PM10", 1, 1000),
  variable = paste0(air$pollutant, "_", air$used_network))
station_input = rbind(air_input, kma_input[names(air_input)])
stopifnot(!anyDuplicated(station_input[c("station_id", "year", "month", "variable")]))
# 좌표 사전은 EPSG4326에서 EPSG5179로 변환한 값입니다.
# 새 관측소 좌표를 추가할 때에는 sf::st_transform(..., 5179)로 사전도 갱신해야 합니다.
xy = read_data("coordinate_5179_lookup.csv")
station_input = merge(station_input, xy, by = c("longitude", "latitude"), all.x = TRUE)
stopifnot(all(is.finite(station_input$x)), all(is.finite(station_input$y)))
save_data(station_input, "interpolation_station_input.csv")
