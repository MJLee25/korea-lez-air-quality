script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
options(lez.analysis.mode = "setup")
source(file.path(dirname(script), "monthly_analysis_journal.R"))
options(lez.analysis.mode = NULL)
reference <- read.csv(file.path(out, "event_group_time.csv"))
warning_rows <- list()
checks <- list()
for (nm in names(panels)) for (method in c("reg", "dr")) {
  z <- panels[[nm]] %>% dplyr::select(id, time, g, all_of(outcomes), all_of(full))
  for (v in full) z[[v]] <- as.numeric(scale(z[[v]]))
  for (y in outcomes) {
    messages <- character()
    set.seed(20260907)
    m <- withCallingHandlers(
      att_gt(yname = y, tname = "time", idname = "id", gname = "g", data = z,
        control_group = "notyettreated", base_period = "universal", est_method = method,
        xformla = reformulate(full), bstrap = TRUE, cband = TRUE, biters = 1999,
        print_details = FALSE),
      warning = function(w) {messages <<- c(messages, conditionMessage(w)); invokeRestart("muffleWarning")})
    old <- reference[reference$dataset == nm & reference$estimator == method & reference$outcome == y, ]
    stopifnot(identical(as.numeric(old$group), as.numeric(m$group)), identical(as.numeric(old$time), as.numeric(m$t)))
    error <- max(abs(old$estimate - m$att), na.rm = TRUE)
    stopifnot(error < 1e-9)
    checks[[length(checks) + 1L]] <- data.frame(dataset = nm, estimator = method, outcome = y, max_att_discrepancy = error)
    if (length(messages)) warning_rows[[length(warning_rows) + 1L]] <- data.frame(dataset = nm, estimator = method, outcome = y, warning = messages)
    message(nm, " ", method, " ", y, ": ", paste(unique(messages), collapse = "; "))
  }
}
write_csv(bind_rows(warning_rows), "event_warning_audit")
write_csv(bind_rows(checks), "event_repeat_check")
