# Journal workflow: revised separately from the preserved earlier script.
# Reconstruct the fitted within-SDM criterion and evaluate its joint information
# and calendar-time score HAC covariance. No district rows are resampled.
suppressPackageStartupMessages({library(dplyr); library(numDeriv)})
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
options(lez.analysis.mode = "setup")
source(file.path(dirname(script), "monthly_analysis_journal.R"))
options(lez.analysis.mode = NULL)
raw_input <- read.csv(file.path(out, "sdm_raw.csv"))
stopifnot(!any(raw_input$specification == "road_control"))
inference_dir <- file.path(out, "inference_cache_journal")
dir.create(inference_dir, showWarnings = FALSE)
file_signature <- paste(tools::md5sum(c(script, file.path(dirname(script), "monthly_analysis_journal.R"),
  file.path(out, "sdm_raw.csv"), input_paths)), collapse = "|")

demean <- function(x, n) {
  m <- matrix(x, nrow = n)
  as.vector(sweep(sweep(m, 1, rowMeans(m), "-"), 2, colMeans(m), "-") + mean(m))
}
design_for <- function(s) {
  z <- d; controls <- full; k <- 5
  if (s %in% c("nearest", "nearest_trends")) z <- nearest_panel
  seasons <- c("Winter", "Spring", "Summer", "Autumn")
  if (s %in% seasons) z <- z[z$season == s, ]
  if (startsWith(s, "trend_")) z <- z[z$season == sub("trend_", "", s), ]
  if (s == "may_june") z <- z[z$month %in% 5:6, ]
  if (s == "no_transport") controls <- setdiff(full, c("daily_km", "cars_per_capita"))
  if (s == "k3") k <- 3
  if (s == "k7") k <- 7
  if (startsWith(s, "omit")) z <- z[z$g != as.numeric(sub("omit", "", s)), ]
  if (s == "start2013") z <- z[z$year >= 2013, ]
  if (s == "core2024") controls <- core
  if (s %in% c("jan2018", "jan2018_trends")) {
    z$g[z$g == 79] <- 73
    z$lez <- as.numeric(z$g > 0 & z$time >= z$g)
  }
  if (s %in% c("jul2020", "jul2020_trends", "dec2020", "dec2020_trends")) {
    z$g[z$cohort == 97] <- if (startsWith(s, "jul")) 103 else 108
    z$lez <- as.numeric(z$g > 0 & z$time >= z$g)
  }
  for (v in controls) z[[v]] <- as.numeric(scale(z[[v]]))
  if (s == "trends" || endsWith(s, "_trends") || startsWith(s, "trend_")) {
    for (g0 in c(61, 79, 97)) z[[paste0("trend", g0)]] <- as.numeric(z$cohort == g0) * (z$time - 60) / 12
    controls <- c(controls, paste0("trend", c(61, 79, 97)))
  }
  z <- z[order(z$time, z$id), ]
  ids <- sort(unique(z$id)); times <- sort(unique(z$time)); n <- length(ids)
  stopifnot(nrow(z) == n * length(times), identical(z$id, rep(ids, length(times))))
  W <- listw2mat(make_w(ids, k))
  X0 <- as.matrix(z[c("lez", controls)])
  WX <- apply(X0, 2, function(v) as.vector(W %*% matrix(v, nrow = n)))
  colnames(WX) <- paste0("w_", colnames(X0))
  X <- apply(cbind(X0, WX), 2, demean, n = n)
  list(z = z, n = n, times = times, W = W, X = X,
    ev = eigen(W, only.values = TRUE)$values)
}

score_hac <- function(scores, times, lag) {
  full_times <- seq(min(times), max(times))
  S <- matrix(0, length(full_times), ncol(scores))
  S[match(times, full_times), ] <- sweep(scores, 2, colMeans(scores), "-")
  meat <- crossprod(S)
  for (h in seq_len(min(lag, nrow(S) - 1))) {
    G <- crossprod(S[(h + 1):nrow(S), , drop = FALSE], S[1:(nrow(S) - h), , drop = FALSE])
    meat <- meat + (1 - h / (lag + 1)) * (G + t(G))
  }
  (meat + t(meat)) / 2
}

quantities <- function(b, V, ev, gradient_only = FALSE) {
  rho <- b["lambda"]; beta <- b["lez"]; theta <- b["w_lez"]
  direct <- Re(mean((beta + theta * ev) / (1 - rho * ev)))
  total <- (beta + theta) / (1 - rho)
  gd <- gt <- setNames(rep(0, length(b)), names(b))
  gd["lambda"] <- Re(mean((beta + theta * ev) * ev / (1 - rho * ev)^2))
  gd["lez"] <- Re(mean(1 / (1 - rho * ev)))
  gd["w_lez"] <- Re(mean(ev / (1 - rho * ev)))
  gt["lambda"] <- (beta + theta) / (1 - rho)^2
  gt[c("lez", "w_lez")] <- 1 / (1 - rho)
  J <- rbind(gd, gt - gd, gt)
  if (gradient_only) return(J)
  se <- sqrt(diag(J %*% V %*% t(J)))
  est <- as.numeric(c(direct, total - direct, total))
  data.frame(component = c("Direct", "Indirect", "Total"), estimate = est,
    se = se, low = est - 1.96 * se, high = est + 1.96 * se,
    p = 2 * pnorm(abs(est / se), lower.tail = FALSE))
}

# Check gap handling against a direct pairwise Bartlett kernel calculation.
test_times <- c(1, 2, 3, 13, 14, 25)
test_scores <- cbind(c(2, -3, 1, 4, -2, 1), c(1, 3, -2, 0, 5, -1))
test_centered <- sweep(test_scores, 2, colMeans(test_scores), "-")
kernel_errors <- vapply(c(6, 12, 24), function(L) {
  K <- pmax(1 - abs(outer(test_times, test_times, "-")) / (L + 1), 0)
  max(abs(score_hac(test_scores, test_times, L) - crossprod(test_centered, K %*% test_centered)))
}, numeric(1))
stopifnot(max(kernel_errors) < 1e-10)

evaluate <- function(s, y, des) {
  cache <- file.path(inference_dir, paste0(s, "_", y, ".rds"))
  if (file.exists(cache)) {
    existing <- readRDS(cache)
    if (identical(existing$signature, file_signature)) return(existing)
  }
  X <- des$X; n <- des$n; times <- des$times; T <- length(times); NT <- n * T
  yt <- demean(des$z[[y]], n)
  # Match splm 1.6-5: spatial lag is applied after two-way demeaning of Y.
  wy <- as.vector(des$W %*% matrix(yt, nrow = n))
  br <- raw_input[raw_input$specification == s & raw_input$outcome == y, ]
  b <- setNames(br$estimate, br$term)[c("lambda", colnames(X))]
  stopifnot(!anyNA(b))
  rho <- b[1]; e <- as.vector(yt - rho * wy - X %*% b[-1]); s2 <- mean(e^2)
  ev <- des$ev; trQ <- Re(sum(ev / (1 - rho * ev)))
  trQQ <- Re(sum((ev / (1 - rho * ev))^2))
  p <- length(b); theta <- c(b, log_sigma2 = log(s2))
  score <- cbind(lambda = colSums(matrix(wy * e / s2, nrow = n)) - trQ,
    apply(X, 2, function(x) colSums(matrix(x * e / s2, nrow = n))),
    log_sigma2 = colSums(matrix(e^2 / (2 * s2), nrow = n)) - n / 2)
  colnames(score) <- names(theta)
  Z <- cbind(lambda = wy, X)
  H <- matrix(0, p + 1, p + 1, dimnames = list(names(theta), names(theta)))
  H[1:p, 1:p] <- crossprod(Z) / s2
  H[1, 1] <- H[1, 1] + T * trQQ
  H[1:p, p + 1] <- H[p + 1, 1:p] <- as.vector(crossprod(Z, e)) / s2
  H[p + 1, p + 1] <- sum(e^2) / (2 * s2)
  bread <- solve(H)
  score_error <- max(abs(colSums(score)) / sqrt(diag(H)))
  coefficient_error <- max(abs(as.vector(qr.solve(X, yt - rho * wy)) - b[-1]))
  stopifnot(score_error < 1e-3, coefficient_error < 1e-7,
    min(eigen(H, symmetric = TRUE, only.values = TRUE)$values) > 0)
  numeric_error <- NA_real_
  if (s == "monthly" && y %in% c("NO2", "CO")) {
    gradient <- function(th) {
      r <- th[1]; v <- exp(th[p + 1]); er <- as.vector(yt - Z %*% th[1:p])
      g <- as.vector(crossprod(Z, er)) / v
      g[1] <- g[1] - T * Re(sum(ev / (1 - r * ev)))
      c(g, -NT / 2 + sum(er^2) / (2 * v))
    }
    Hnum <- -numDeriv::jacobian(gradient, theta)
    numeric_error <- max(abs(Hnum - H) / pmax(1, sqrt(outer(diag(H), diag(H)))))
    stopifnot(numeric_error < 1e-5)
  }
  covariances <- list(Joint_OIM = bread[1:p, 1:p])
  for (lag in c(6, 12, 24)) {
    V <- bread %*% score_hac(score, times, lag) %*% bread
    covariances[[paste0("HAC", lag)]] <- V[1:p, 1:p, drop = FALSE]
  }
  for (V in covariances) {
    scale_V <- max(1, max(abs(V)))
    stopifnot(max(abs(V - t(V))) / scale_V < 1e-9,
      min(eigen((V + t(V)) / 2, symmetric = TRUE, only.values = TRUE)$values) / scale_V > -1e-9)
  }
  J <- quantities(b, covariances$HAC12, ev, gradient_only = TRUE)
  Jnum <- numDeriv::jacobian(function(v) {
    quantities(setNames(v, names(b)), covariances$HAC12, ev)$estimate
  }, b)
  delta_error <- max(abs(J - Jnum) / pmax(1, abs(J)))
  stopifnot(delta_error < 1e-5)
  common <- data.frame(specification = s, outcome = y, n = NT, units = n, periods = T)
  ref <- mean(des$z[[y]][des$z$g > 0 & des$z$time < des$z$g])
  impacts <- bind_rows(lapply(names(covariances), function(nm) {
    q <- quantities(b, covariances[[nm]], ev)
    cbind(common, covariance = nm, q, rho = unname(rho), pre_mean = ref,
      relative_percent = 100 * q$estimate / ref)
  }))
  coefs <- bind_rows(lapply(names(covariances), function(nm) {
    se <- sqrt(diag(covariances[[nm]]))
    cbind(common, covariance = nm, term = names(b), estimate = as.numeric(b), se = se,
      p = 2 * pnorm(abs(b / se), lower.tail = FALSE))
  }))
  residuals <- matrix(e, nrow = n)
  ar <- function(lag) {
    right <- match(times + lag, times); left <- which(!is.na(right))
    if (length(left) < 3) return(rep(NA_real_, n))
    vapply(seq_len(n), function(i) cor(residuals[i, left], residuals[i, right[left]]), numeric(1))
  }
  ar1 <- ar(1); ar12 <- ar(12)
  moran <- apply(residuals, 2, function(v) {
    v <- v - mean(v)
    as.numeric(crossprod(v, des$W %*% v) / crossprod(v))
  })
  diagnostics <- cbind(common, ar1_median = median(ar1, na.rm = TRUE),
    ar1_q25 = quantile(ar1, .25, na.rm = TRUE), ar1_q75 = quantile(ar1, .75, na.rm = TRUE),
    ar12_median = median(ar12, na.rm = TRUE), moran_median = median(moran),
    moran_q25 = quantile(moran, .25), moran_q75 = quantile(moran, .75),
    score_error = score_error, coefficient_error = coefficient_error, hessian_numeric_error = numeric_error,
    delta_gradient_error = delta_error,
    information_rcond = rcond(H), joint_rho_lez_covariance = bread["lambda", "lez"],
    joint_rho_wlez_covariance = bread["lambda", "w_lez"])
  ans <- list(signature = file_signature, impacts = impacts, coefs = coefs,
    diagnostics = diagnostics, covariances = covariances, scores = score, information = H)
  saveRDS(ans, cache)
  message(s, " ", y, ": OIM/HAC12 total SE ",
    paste(round(impacts$se[impacts$component == "Total" & impacts$covariance %in% c("Joint_OIM", "HAC12")], 3), collapse = "/"))
  ans
}

specs <- setdiff(unique(raw_input$specification), "core2025")
if ("probe" %in% commandArgs(trailingOnly = TRUE)) specs <- "monthly"
results <- list()
for (s in specs) {
  des <- design_for(s)
  ys <- unique(raw_input$outcome[raw_input$specification == s])
  for (y in ys) results[[paste(s, y)]] <- evaluate(s, y, des)
}
write_csv(bind_rows(lapply(results, `[[`, "impacts")), "inference_impacts")
write_csv(bind_rows(lapply(results, `[[`, "coefs")), "inference_coefficients")
write_csv(bind_rows(lapply(results, `[[`, "diagnostics")), "residual_diagnostics")
diagnostics <- bind_rows(lapply(results, `[[`, "diagnostics"))
report <- c("Joint-information and calendar-time score-HAC verification: PASS",
  paste("Verified outcome/specification combinations:", length(results)),
  "All four covariance matrices are symmetric and positive semidefinite to numerical tolerance.",
  paste("Maximum pairwise-kernel discrepancy with calendar gaps:", format(max(kernel_errors), scientific = TRUE)),
  paste("Maximum scaled analytic/numeric impact-gradient discrepancy:", format(max(diagnostics$delta_gradient_error), scientific = TRUE)),
  paste("Maximum scaled analytic/numeric information discrepancy (primary NO2 and CO):", format(max(diagnostics$hessian_numeric_error, na.rm = TRUE), scientific = TRUE)),
  "These are computational checks, not a validation of the identifying or dependence assumptions.")
writeLines(report, file.path(out, "inference_verification.txt"))
cat(paste(report, collapse = "\n"), "\n")
