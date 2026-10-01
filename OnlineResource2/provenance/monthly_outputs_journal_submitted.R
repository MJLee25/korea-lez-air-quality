# Journal workflow: revised separately from the preserved earlier script.
suppressPackageStartupMessages({library(dplyr); library(ggplot2)})
arg <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
paper <- normalizePath(file.path(dirname(arg), ".."))
out <- file.path(paper, "monthly_results")
tables <- file.path(paper, "tables")
dir.create(tables, showWarnings = FALSE)
inference <- read.csv(file.path(out, "inference_impacts.csv"))
stopifnot(!any(inference$specification == "road_control"))
imp <- subset(inference, covariance == "HAC12")
tw <- read.csv(file.path(out, "sdm_twfe.csv"))
raw <- subset(read.csv(file.path(out, "inference_coefficients.csv")), covariance == "HAC12")
event <- read.csv(file.path(out, "event_dynamic.csv"))
pre <- read.csv(file.path(out, "event_summary.csv"))
summ <- read.csv(file.path(out, "summary_statistics.csv"))
ys <- c("NO2", "CO", "SO2", "O3", "PM10")
tex_y <- setNames(c("NO$_2$", "CO", "SO$_2$", "O$_3$", "PM$_{10}$"), ys)
plot_y <- setNames(c("NO[2]~(ppb)", "CO~(ppb)", "SO[2]~(ppb)", "O[3]~(ppb)", "PM[10]~(mu*g~m^{-3})"), ys)
num <- function(x, digits = 3) formatC(x, format = "f", digits = digits)
pval <- function(x) ifelse(is.na(x), "n.a.", ifelse(x < .001, "$<0.001$", num(x, 4)))
row <- function(...) paste0(paste(c(...), collapse = " & "), " \\\\")
save_table <- function(name, lines) writeLines(lines, file.path(tables, paste0(name, ".tex")))

lines <- c("\\begin{tabular}{lrrrrr}", "\\toprule", row("Outcome", "Mean", "SD", "Minimum", "Maximum", "Pre-LEZ mean"), "\\midrule")
for (y in ys) {
  z <- summ[summ$outcome == y, ]
  lines <- c(lines, row(tex_y[y], num(z$mean), num(z$sd), num(z$min), num(z$max), num(z$treated_pre_mean)))
}
save_table("monthly_summary", c(lines, "\\bottomrule", "\\end{tabular}"))

lines <- c("\\begin{tabular}{lrrrrr}", "\\toprule", row("Outcome", "TWFE", "Direct", "Indirect", "Total", "Total/mean (\\%)"), "\\midrule")
for (y in ys) {
  z <- imp[imp$specification == "monthly" & imp$outcome == y, ]
  z <- z[match(c("Direct", "Indirect", "Total"), z$component), ]
  t <- tw[tw$specification == "monthly" & tw$outcome == y, ]
  lines <- c(lines, row(tex_y[y], num(t$estimate), num(z$estimate), num(z$relative_percent[3], 1)),
    row("", paste0("(", num(t$se), ")"), paste0("(", num(z$se), ")"), ""), "\\addlinespace[3pt]")
}
save_table("monthly_primary", c(lines, "\\bottomrule", "\\end{tabular}"))

spec_labels <- c(monthly = "Monthly baseline", trends = "Cohort trends", no_transport = "Omit transport controls",
  k3 = "$k=3$", k7 = "$k=7$", omit61 = "Omit Seoul cohort", omit79 = "Omit July 2018 cohort",
  omit97 = "Omit January 2020 cohort", start2013 = "Start in 2013",
  core2024 = "Omit land-use controls", jan2018 = "2018 cohort starts January",
  nearest = "Nearest interpolation", nearest_trends = "Nearest + cohort trends")
make_spec_table <- function(names_use, name, include_se = TRUE, labels = spec_labels) {
  lines <- c("\\begin{tabular}{lrrrrr}", "\\toprule", row("Specification", tex_y), "\\midrule")
  for (s in names_use) {
    z <- imp[imp$specification == s & imp$component == "Total", ]
    z <- z[match(ys, z$outcome), ]
    stopifnot(nrow(z) == 5, !anyNA(z$outcome))
    lines <- c(lines, row(labels[s], num(z$estimate)))
    if (include_se) lines <- c(lines, row("", paste0("(", num(z$se), ")")), "\\addlinespace[3pt]")
  }
  save_table(name, c(lines, "\\bottomrule", "\\end{tabular}"))
}
make_spec_table(c("monthly", "trends", "omit61", "omit79", "omit97"), "monthly_sensitivity_main")
make_spec_table(c("k3", "k7", "no_transport", "start2013", "core2024", "jan2018"), "monthly_sensitivity_extra")
make_spec_table(c("monthly", "nearest", "trends", "nearest_trends"), "interpolation_sensitivity",
  labels = c(monthly = "IDW baseline", nearest = "Nearest baseline", trends = "IDW + cohort trends", nearest_trends = "Nearest + cohort trends"))

lines <- c("\\begin{tabular}{llrrrrr}", "\\toprule", row("Period", "Estimator", tex_y), "\\midrule")
for (nm in c("dat12_24", "dat13_24")) for (method in c("reg", "dr")) {
  z <- pre[pre$dataset == nm & pre$estimator == method, ]; z <- z[match(ys, z$outcome), ]
  label <- c(dat12_24 = "2012--2024", dat13_24 = "2013--2024", dat12_25 = "2012--2025")[nm]
  lines <- c(lines, row(label, method, pval(z$max_t_p)))
}
save_table("monthly_pretests", c(lines, "\\bottomrule", "\\end{tabular}"))

lines <- c("\\begin{tabular}{llrrrr}", "\\toprule", row("Season", "Outcome", "Direct", "Indirect", "Total", "Trend-adjusted total"), "\\midrule")
for (s in c("Winter", "Spring", "Summer", "Autumn")) {
  for (y in ys) {
    z <- imp[imp$specification == s & imp$outcome == y, ]
    z <- z[match(c("Direct", "Indirect", "Total"), z$component), ]
    tr <- imp[imp$specification == paste0("trend_", s) & imp$outcome == y & imp$component == "Total", ]
    stopifnot(nrow(tr) == 1)
    lines <- c(lines, row(if (y == "NO2") s else "", tex_y[y], num(z$estimate), num(tr$estimate)),
      row("", "", paste0("(", num(z$se), ")"), paste0("(", num(tr$se), ")")))
  }
  lines <- c(lines, "\\addlinespace[4pt]")
}
save_table("monthly_seasons", c(lines, "\\bottomrule", "\\end{tabular}"))

coef_names <- c(lambda = "$\\rho$", lez = "LEZ", pop_density = "Population density", industrial_area = "Industrial area/person",
  commercial_area = "Commercial area/person", green_area_per_capita = "Green area/person", daily_km = "Daily vehicle distance",
  cars_per_capita = "Cars/person", avg_temp = "Temperature", sun_time = "Sunshine", stagnant_days = "Low-wind equivalent days",
  avg_wind = "Wind speed", avg_humid = "Humidity", avg_rain = "Precipitation")
terms <- raw$term[raw$specification == "monthly" & raw$outcome == "NO2"]
lines <- c("\\begin{longtable}{lrrrrr}", "\\caption{Monthly SDM coefficients with standardized covariates}\\label{tab:s_coefficients}\\\\", "\\toprule",
 row("Term", tex_y), "\\midrule\\endfirsthead", "\\multicolumn{6}{c}{Table S4 (continued)}\\\\", "\\toprule", row("Term", tex_y), "\\midrule\\endhead", "\\bottomrule\\endfoot")
for (term in terms) {
  z <- raw[raw$specification == "monthly" & raw$term == term, ]; z <- z[match(ys, z$outcome), ]
  label <- if (startsWith(term, "w_")) paste0("$W$ $\\times$ ", coef_names[sub("^w_", "", term)]) else coef_names[term]
  lines <- c(lines, paste0(row(label, num(z$estimate)), "*"), row("", paste0("(", num(z$se), ")")), "\\addlinespace[1pt]")
}
save_table("monthly_coefficients", c(lines, "\\end{longtable}"))

diagnostics <- subset(read.csv(file.path(out, "residual_diagnostics.csv")), specification == "monthly")
lines <- c("\\begin{tabular}{lrrrr}", "\\toprule", row("Outcome", "Lag-1 median", "Lag-1 IQR", "Lag-12 median", "Moran's $I$ median"), "\\midrule")
for (y in ys) {
  z <- diagnostics[diagnostics$outcome == y, ]
  lines <- c(lines, row(tex_y[y], num(z$ar1_median), paste0("[", num(z$ar1_q25), ", ", num(z$ar1_q75), "]"), num(z$ar12_median), num(z$moran_median)))
}
save_table("monthly_residuals", c(lines, "\\bottomrule", "\\end{tabular}"))

lines <- c("\\begin{tabular}{lrrrrrr}", "\\toprule", row("Outcome", "Estimate", "OIM SE", "HAC(6) SE", "HAC(12) SE", "HAC(24) SE", "HAC(12) 95\\% CI"), "\\midrule")
for (y in ys) {
  z <- inference[inference$specification == "monthly" & inference$outcome == y & inference$component == "Total", ]
  z <- z[match(c("Joint_OIM", "HAC6", "HAC12", "HAC24"), z$covariance), ]
  lines <- c(lines, row(tex_y[y], num(z$estimate[3]), num(z$se), paste0("[", num(z$low[3]), ", ", num(z$high[3]), "]")))
}
save_table("monthly_uncertainty", c(lines, "\\bottomrule", "\\end{tabular}"))

if ("--tables-only" %in% commandArgs(trailingOnly = TRUE)) quit(save = "no")

theme_paper <- theme_bw(base_size = 13, base_family = "serif") +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(linewidth = .2, colour = "grey90"),
    strip.background = element_rect(fill = "grey95"), strip.text = element_text(size = 13),
    axis.title = element_text(size = 13), legend.position = "bottom", plot.margin = margin(10, 14, 10, 10))
ep <- event %>% filter(dataset == "dat12_24", estimator == "reg", event_month != -1) %>%
  mutate(pollutant = factor(outcome, levels = ys, labels = plot_y))
p <- ggplot(ep, aes(event_month, estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = .4) +
  geom_vline(xintercept = -.5, linetype = "dotted", linewidth = .4) +
  geom_ribbon(aes(ymin = low, ymax = high), fill = "#4a7087", alpha = .20) +
  geom_line(colour = "#1c526b", linewidth = .45) + geom_point(colour = "#1c526b", size = .7) +
  facet_wrap(~pollutant, ncol = 2, scales = "free_y", labeller = label_parsed) +
  scale_x_continuous(breaks = seq(-48, 60, 12)) + labs(x = "Months relative to LEZ adoption", y = "Group-time contrast") + theme_paper
ggsave(file.path(paper, "Fig2_monthly.pdf"), p, width = 6.5, height = 7.2)
ggsave(file.path(paper, "Fig2_monthly.png"), p, width = 6.5, height = 7.2, dpi = 320)

sp <- imp %>% filter(specification %in% c("Winter", "Spring", "Summer", "Autumn"), component == "Total") %>%
  mutate(season = factor(specification, levels = c("Autumn", "Summer", "Spring", "Winter")),
    pollutant = factor(outcome, levels = ys, labels = plot_y))
p <- ggplot(sp, aes(estimate, season, colour = season)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = .4, colour = "grey40") +
  geom_segment(aes(x = low, xend = high, yend = season), linewidth = .8) +
  geom_point(size = 2.7) + facet_wrap(~pollutant, ncol = 2, scales = "free_x", labeller = label_parsed) +
  scale_colour_manual(values = c(Autumn = "#966831", Summer = "#b64939", Spring = "#438568", Winter = "#326486"), guide = "none") +
  labs(x = "Total spatial association", y = NULL) + theme_paper
ggsave(file.path(paper, "Fig3_seasonal.pdf"), p, width = 6.5, height = 6.5)
ggsave(file.path(paper, "Fig3_seasonal.png"), p, width = 6.5, height = 6.5, dpi = 320)

ep <- event %>% filter(dataset == "dat12_24", estimator == "dr", event_month != -1) %>%
  mutate(pollutant = factor(outcome, levels = ys, labels = plot_y))
p <- ggplot(ep, aes(event_month, estimate)) +
  geom_hline(yintercept = 0, linetype = "dashed", linewidth = .4) +
  geom_vline(xintercept = -.5, linetype = "dotted", linewidth = .4) +
  geom_ribbon(aes(ymin = low, ymax = high), fill = "#8e5944", alpha = .20) +
  geom_line(colour = "#8e5944", linewidth = .45) + geom_point(colour = "#8e5944", size = .7) +
  facet_wrap(~pollutant, ncol = 2, scales = "free_y", labeller = label_parsed) +
  scale_x_continuous(breaks = seq(-48, 60, 12)) + labs(x = "Months relative to LEZ adoption", y = "Doubly robust group-time contrast") + theme_paper
ggsave(file.path(paper, "FigS1_monthly_dr.pdf"), p, width = 6.5, height = 7.2)

cat("Generated monthly tables and figures\n")
