args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[1] else "public"
if (!mode %in% c("public", "models")) stop("Use public or models")
p <- c("dplyr", "ggplot2", "sf", "spdep")
if (mode == "models") p <- unique(c(p, "readxl", "tidyr", "splm", "plm", "did", "geojsonsf", "numDeriv"))
repo <- "https://cloud.r-project.org"
available <- available.packages(repos = repo)
if (!nrow(available)) stop("Cannot read the CRAN package index")
needed <- unique(c(p, unlist(tools::package_dependencies(p, available, recursive = TRUE))))
needed <- intersect(needed, rownames(available))
install.packages(needed, repos = repo)
ok <- vapply(p, requireNamespace, logical(1), quietly = TRUE)
if (!all(ok)) stop("Missing packages: ", paste(p[!ok], collapse = ", "))
print(sessionInfo())
