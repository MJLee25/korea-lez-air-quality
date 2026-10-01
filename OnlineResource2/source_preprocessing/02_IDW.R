# 제공 격자와 면적가중치는 2019 경계의 EPSG5179 교차면적으로 계산했습니다.
# 각 격자 중심에서 IDW 후 시군구별 면적가중 평균을 냅니다.
library(Matrix)
grid = read_data("grid_points.csv")
weights = read_data("grid_area_weights.csv")
ids = sort(unique(weights$ID))
A = sparseMatrix(i = match(weights$ID, ids), j = weights$grid_id, x = weights$weight,
  dims = c(length(ids), nrow(grid)))
stopifnot(max(abs(rowSums(A) - 1)) < 1e-8)
groups = split(seq_len(nrow(station_input)), paste(station_input$year, station_input$month, station_input$variable, sep = "|"))
idw_one = function(ii) {
  z = station_input[ii, ]; stopifnot(nrow(z) >= 3)
  d2 = outer(grid$x, z$x, "-")^2 + outer(grid$y, z$y, "-")^2
  w = 1 / pmax(d2, 1e-16); hit = d2 < 1e-16
  exact = rowSums(hit) > 0
  w[exact, ] = hit[exact, , drop = FALSE]
  w = w / rowSums(w)
  data.frame(ID = ids, year = z$year[1], month = z$month[1], variable = z$variable[1],
    value = as.numeric(A %*% (w %*% z$value)))
}
# 테스트 시 EMA_RE_SMOKE=1: 일부 월만 계산하여 수치 대조합니다.
if (Sys.getenv("EMA_RE_SMOKE") == "1") groups = groups[c("2012|1|avg_rain", "2019|5|avg_wind", "2024|12|NO2_도시대기")]
idw_results = do.call(rbind, lapply(groups, idw_one))
save_data(idw_results, "idw_results.csv")

