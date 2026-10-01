suppressPackageStartupMessages({library(dplyr); library(ggplot2)})
arg <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
paper <- normalizePath(file.path(dirname(arg), ".."))
imp <- read.csv(file.path(paper, "monthly_results", "inference_impacts.csv"))
seasons <- c("Winter", "Spring", "Summer", "Autumn")
ys <- c("NO2", "CO", "SO2", "O3", "PM10")
labels <- c("NO[2]~(ppb)", "CO~(ppb)", "SO[2]~(ppb)", "O[3]~(ppb)",
  "PM[10]~(mu*g~m^{-3})")
sp <- imp %>% filter(covariance == "HAC12", component == "Total",
  specification %in% c(seasons, paste0("trend_", seasons))) %>%
  mutate(season = factor(sub("^trend_", "", specification), levels = rev(seasons)),
    model = factor(ifelse(startsWith(specification, "trend_"), "Cohort trends", "Baseline"),
      levels = c("Baseline", "Cohort trends")),
    y_position = as.numeric(season) + ifelse(model == "Baseline", .12, -.12),
    pollutant = factor(outcome, levels = ys, labels = labels))
stopifnot(nrow(sp) == 40L, all(sp$periods == 39L), all(sp$units == 247L),
  all(is.finite(sp$estimate)), all(sp$low <= sp$high))

# Keep both specifications on the same pollutant-specific axis.
p <- ggplot(sp, aes(estimate, y_position, colour = model, shape = model)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = .4, colour = "grey45") +
  geom_segment(aes(x = low, xend = high, yend = y_position), linewidth = .6) +
  geom_point(size = 2.5, stroke = .8) +
  facet_wrap(~pollutant, ncol = 2, scales = "free_x", labeller = label_parsed) +
  scale_y_continuous(breaks = 1:4, labels = rev(seasons), limits = c(.6, 4.4)) +
  scale_colour_manual(values = c(Baseline = "#1c526b", "Cohort trends" = "#9b4c32")) +
  scale_shape_manual(values = c(Baseline = 16, "Cohort trends" = 1)) +
  labs(x = "Total spatial association", y = NULL, colour = NULL, shape = NULL) +
  theme_bw(base_size = 12, base_family = "serif") +
  theme(panel.grid.minor = element_blank(),
    panel.grid.major = element_line(linewidth = .2, colour = "grey92"),
    strip.background = element_rect(fill = "grey96"), strip.text = element_text(size = 13),
    legend.position = "bottom", legend.text = element_text(size = 12),
    plot.margin = margin(8, 12, 8, 8))
ggsave(file.path(paper, "Fig3_journal.pdf"), p, width = 6.5, height = 6.5, device = grDevices::cairo_pdf)
ggsave(file.path(paper, "Fig3_journal.png"), p, width = 6.5, height = 6.5, dpi = 320)
cat("Generated Fig3_journal: 40 seasonal estimates with matched trend comparisons\n")
