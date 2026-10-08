#################################################
# 07. Parallel Trends and Seasonal Results Figures
#################################################

# Run after setting the working directory to the repository root.
# Outputs: Fig 2, Fig 3, Fig S1: PDF, PNG, and CSV

##### Packages
library(dplyr)
library(ggplot2)


#################################################
# Load Parallel Trends Results
#################################################

event = read.csv("result/_intermediate/event_dynamic.csv")

ys = c("NO2", "CO", "SO2", "O3", "PM10")

plot_y = setNames(
  c("NO[2]~(ppb)", "CO~(ppb)", "SO[2]~(ppb)", "O[3]~(ppb)", "PM[10]~(mu*g~m^{-3})"),
  ys
)


#################################################
# Figure Formatting
#################################################

theme_paper = theme_bw(base_size = 13, base_family = "serif") + theme(
  panel.grid.minor = element_blank(),
  panel.grid.major = element_line(linewidth = 0.2, colour = "grey90"), strip.background = element_rect(fill = "grey95"),
  strip.text = element_text(size = 13), axis.title = element_text(size = 13),
  legend.position = "bottom", plot.margin = margin(10, 14, 10, 10)
)

ep = event %>%
  filter(dataset == "dat12_24", estimator == "reg", event_month !=
    -1) %>%
  mutate(pollutant = factor(outcome, levels = ys, labels = plot_y))

p = ggplot(ep, aes(event_month, estimate)) +
  geom_hline(
    yintercept = 0, linetype = "dashed",
    linewidth = 0.4
  ) +
  geom_vline(xintercept = -0.5, linetype = "dotted", linewidth = 0.4) +
  geom_ribbon(aes(ymin = low, ymax = high), fill = "#4a7087", alpha = 0.2) +
  geom_line(colour = "#1c526b", linewidth = 0.45) +
  geom_point(
    colour = "#1c526b",
    size = 0.7
  ) +
  facet_wrap(~pollutant, ncol = 2, scales = "free_y", labeller = label_parsed) +
  scale_x_continuous(breaks = seq(-48, 60, 12)) +
  labs(
    x = "Months relative to LEZ adoption",
    y = "Group-time contrast"
  ) +
  theme_paper

ggsave("result/Fig 2.pdf", p, width = 6.5, height = 7.2)

ggsave("result/Fig 2.png", p, width = 6.5, height = 7.2, dpi = 320)

ep = event %>%
  filter(dataset == "dat12_24", estimator == "dr", event_month !=
    -1) %>%
  mutate(pollutant = factor(outcome, levels = ys, labels = plot_y))

p = ggplot(ep, aes(event_month, estimate)) +
  geom_hline(
    yintercept = 0, linetype = "dashed",
    linewidth = 0.4
  ) +
  geom_vline(xintercept = -0.5, linetype = "dotted", linewidth = 0.4) +
  geom_ribbon(aes(ymin = low, ymax = high), fill = "#8e5944", alpha = 0.2) +
  geom_line(colour = "#8e5944", linewidth = 0.45) +
  geom_point(
    colour = "#8e5944",
    size = 0.7
  ) +
  facet_wrap(~pollutant, ncol = 2, scales = "free_y", labeller = label_parsed) +
  scale_x_continuous(breaks = seq(-48, 60, 12)) +
  labs(
    x = "Months relative to LEZ adoption",
    y = "Doubly robust group-time contrast"
  ) +
  theme_paper

ggsave("result/Fig S1.pdf", p, width = 6.5, height = 7.2)

ggsave("result/Fig S1.png", p, width = 6.5, height = 7.2, dpi = 320)


#################################################
# Load Seasonal Spatial Effects
#################################################

imp = read.csv("result/_intermediate/inference_impacts.csv")

seasons = c("Winter", "Spring", "Summer", "Autumn")

ys = c("NO2", "CO", "SO2", "O3", "PM10")

labels = c("NO[2]~(ppb)", "CO~(ppb)", "SO[2]~(ppb)", "O[3]~(ppb)", "PM[10]~(mu*g~m^{-3})")


#################################################
# Compare Baseline and Cohort-Trend Models
#################################################

sp = imp %>%
  filter(covariance == "HAC12", component == "Total", specification %in%
    c(seasons, paste0("trend_", seasons))) %>%
  mutate(
    season = factor(sub(
      "^trend_",
      "", specification
    ), levels = rev(seasons)), model = factor(ifelse(startsWith(
      specification,
      "trend_"
    ), "Cohort trends", "Baseline"), levels = c("Baseline", "Cohort trends")),
    y_position = as.numeric(season) + ifelse(model == "Baseline", 0.12, -0.12),
    pollutant = factor(outcome, levels = ys, labels = labels)
  )

stopifnot(
  nrow(sp) == 40L, all(sp$periods == 39L), all(sp$units == 247L), all(is.finite(sp$estimate)),
  all(sp$low <= sp$high)
)

p = ggplot(sp, aes(estimate, y_position, colour = model, shape = model)) +
  geom_vline(
    xintercept = 0,
    linetype = "dashed", linewidth = 0.4, colour = "grey45"
  ) +
  geom_segment(aes(
    x = low,
    xend = high, yend = y_position
  ), linewidth = 0.6) +
  geom_point(
    size = 2.5,
    stroke = 0.8
  ) +
  facet_wrap(~pollutant, ncol = 2, scales = "free_x", labeller = label_parsed) +
  scale_y_continuous(breaks = 1:4, labels = rev(seasons), limits = c(0.6, 4.4)) +
  scale_colour_manual(values = c(Baseline = "#1c526b", `Cohort trends` = "#9b4c32")) +
  scale_shape_manual(values = c(Baseline = 16, `Cohort trends` = 1)) +
  labs(
    x = "Total spatial association",
    y = NULL, colour = NULL, shape = NULL
  ) +
  theme_bw(base_size = 12, base_family = "serif") +
  theme(
    panel.grid.minor = element_blank(), panel.grid.major = element_line(
      linewidth = 0.2,
      colour = "grey92"
    ), strip.background = element_rect(fill = "grey96"), strip.text = element_text(size = 13),
    legend.position = "bottom", legend.text = element_text(size = 12), plot.margin = margin(
      8,
      12, 8, 8
    )
  )

ggsave("result/Fig 3.pdf", p, width = 6.5, height = 6.5)

ggsave("result/Fig 3.png", p, width = 6.5, height = 6.5, dpi = 320)

write.csv(subset(event, dataset == "dat12_24" & estimator == "reg" & event_month !=
  -1), "result/Fig 2.csv", row.names = FALSE)

write.csv(subset(event, dataset == "dat12_24" & estimator == "dr" & event_month !=
  -1), "result/Fig S1.csv", row.names = FALSE)

write.csv(subset(imp, covariance == "HAC12" & component == "Total" & specification %in%
  c(seasons, paste0("trend_", seasons))), "result/Fig 3.csv", row.names = FALSE)
