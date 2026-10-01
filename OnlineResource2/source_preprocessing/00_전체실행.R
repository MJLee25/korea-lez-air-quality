# 첫 번째 경로만 수정한 뒤 이 파일을 실행하세요.
project_path = Sys.getenv("EMA_RE_PROJECT", "C:/Users/user/Desktop/EMA_보완자료_분석결과_20260920-re")
input_path = file.path(project_path, "04_검증및재현자료", "재현입력")
output_path = file.path(project_path, "재실행결과")
dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
read_data = function(name) {
  path = file.path(input_path, name)
  if (grepl("[.]gz$", name)) {
    con = gzfile(path, "rt", encoding = "UTF-8")
    on.exit(close(con)); return(read.csv(con, check.names = FALSE))
  }
  read.csv(path, fileEncoding = "UTF-8-BOM", check.names = FALSE)
}
save_data = function(x, name) write.csv(x, file.path(output_path, name), row.names = FALSE, na = "", fileEncoding = "UTF-8")
for (f in c("01_kma_asos_prep.R", "01_airkorea_prep.R", "02_IDW.R", "03_merge_check.R")) {
  cat("실행:", f, "\n"); flush.console()
  source(file.path(project_path, "03_수정코드", f), encoding = "UTF-8")
}

