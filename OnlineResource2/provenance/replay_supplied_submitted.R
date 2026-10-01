# Run the supplied preprocessing in an isolated audit output directory.
args <- commandArgs(trailingOnly = TRUE)
project_path <- normalizePath(args[1])
output_path <- normalizePath(args[2], mustWork = FALSE)
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
subdir <- function(path, prefix) {
  matches <- list.dirs(path, full.names = TRUE, recursive = FALSE)
  result <- matches[startsWith(basename(matches), prefix)]
  stopifnot(length(result) == 1L)
  result
}
evidence <- subdir(project_path, "04_")
input_candidates <- list.dirs(evidence, full.names = TRUE, recursive = FALSE)
input_path <- input_candidates[file.exists(file.path(input_candidates, "annual_covariates.csv"))]
stopifnot(length(input_path) == 1L)
code_path <- subdir(project_path, "03_")
read_data <- function(name) {
  path <- file.path(input_path, name)
  if (grepl("[.]gz$", name)) {
    con <- gzfile(path, "rt", encoding = "UTF-8")
    on.exit(close(con))
    return(read.csv(con, check.names = FALSE))
  }
  read.csv(path, fileEncoding = "UTF-8-BOM", check.names = FALSE)
}
save_data <- function(x, name) {
  write.csv(x, file.path(output_path, name), row.names = FALSE, na = "", fileEncoding = "UTF-8")
}
for (f in c("01_kma_asos_prep.R", "01_airkorea_prep.R", "02_IDW.R", "03_merge_check.R")) {
  cat(format(Sys.time()), f, "\n")
  flush.console()
  source(file.path(code_path, f), encoding = "UTF-8")
}
capture.output(sessionInfo(), file = file.path(output_path, "sessionInfo.txt"))
