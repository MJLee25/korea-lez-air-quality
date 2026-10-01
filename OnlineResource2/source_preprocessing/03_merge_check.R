if (Sys.getenv("EMA_RE_SMOKE") != "1") {
  annual = read_data("annual_covariates.csv")
  stopifnot(!anyDuplicated(annual[c("ID", "year")]))
  panel = reshape(idw_results, idvar = c("ID", "year", "month"), timevar = "variable", direction = "wide")
  names(panel) = sub("^value[.]", "", names(panel))
  final = merge(panel, annual, by = c("ID", "year"), all.x = TRUE)
  final = final[order(final$ID, final$year, final$month), ]
  stopifnot(nrow(final) == 38844, !anyDuplicated(final[c("ID", "year", "month")]), !anyNA(final))
  final$processing_version = "20260920-re"
  final$rain_processing = "published_month_total_matches_daily_sum_full_month_single_coordinate"
  final$air_history_fully_verified = FALSE
  final$stagnant_days_definition = "calendar_equivalent_from_valid_wind_days"
  save_data(final, "final_data.csv")
  save_data(data.frame(variable = names(final), NA_count = colSums(is.na(final))), "missing_counts.csv")
  cat("완료: 38,844행, 전체 열 NA 0개\n")
}
