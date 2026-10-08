#################################################
# 08. Map of Policy Adoption Areas
#################################################

# Run after setting the working directory to the repository root.
# Outputs: Fig 1: PDF and PNG

##### Packages
library(sf)


#################################################
# Load Policy Cohorts and Map Boundaries
#################################################

units = read.csv("result/_intermediate/cohort_membership.csv", encoding = "UTF-8")

geo = readRDS("data/support/map_boundary_2019.rds")

stopifnot(nrow(geo) == 249, !anyDuplicated(geo$id), all(units$id %in% geo$id))

stopifnot(identical(as.character(units$district), as.character(geo$district[match(
  units$id,
  geo$id
)])))

geo$g = units$g[match(geo$id, units$id)]

stopifnot(sum(is.na(geo$g)) == 2)

stopifnot(setequal(geo$district[is.na(geo$g)], c("옹진군", "울릉군")))


#################################################
# Colors by Cohort
#################################################

palette = c(`0` = "#E0F2EB", `61` = "#195C91", `79` = "#25B4A3", `97` = "#FFDA59")

fills = unname(palette[as.character(geo$g)])

fills[is.na(fills)] = "#B8B8B8"


#################################################
# Extent of the Metropolitan Area Enlargement
#################################################

capital = geo[geo$province %in% c("서울특별시", "인천광역시", "경기도") &
  !is.na(geo$g), ]

box = st_bbox(capital)

pad = 12000

zoom_x = unname(box[c("xmin", "xmax")]) + c(-pad, pad)

zoom_y = unname(box[c("ymin", "ymax")]) + c(-pad, pad)

islands = geo[is.na(geo$g), ]

island_xy = st_coordinates(st_centroid(st_geometry(islands), of_largest_polygon = TRUE))


#################################################
# National Map and Enlarged Metropolitan Area Map
#################################################

draw_map = function() {
  layout(matrix(c(1, 2, 3, 3), nrow = 2, byrow = TRUE), heights = c(1, 0.18))
  par(mar = c(0, 0, 2.5, 0), family = "sans")
  plot(st_geometry(geo),
    col = fills, border = "#888888", lwd = 0.22, main = "South Korea",
    cex.main = 1
  )
  rect(zoom_x[1], zoom_y[1], zoom_x[2], zoom_y[2], border = "#B44432", lwd = 1.1)
  points(island_xy, pch = 21, bg = "#555555", col = "white", cex = 0.8)
  for (i in seq_len(nrow(islands))) {
    label = if (islands$district[i] == "옹진군") {
      "Ongjin-gun\n(excluded)"
    } else {
      "Ulleung-gun\n(excluded)"
    }
    text(island_xy[i, 1], island_xy[i, 2], label, pos = if (islands$district[i] ==
      "옹진군") {
      4
    } else {
      3
    }, cex = 0.65, offset = 0.5)
  }
  plot(st_geometry(geo),
    col = fills, border = "#777777", lwd = 0.45, xlim = zoom_x,
    ylim = zoom_y, main = "Capital-region rollout", cex.main = 1
  )
  u = par("usr")
  arrow_x = u[1] + 0.07 * diff(u[1:2])
  arrow_y = u[4] - 0.2 * diff(u[3:4])
  arrows(arrow_x, arrow_y, arrow_x, arrow_y + 0.1 * diff(u[3:4]),
    length = 0.09,
    lwd = 1.2
  )
  text(arrow_x, arrow_y + 0.13 * diff(u[3:4]), "N", cex = 0.8)
  sx = u[1] + 0.07 * diff(u[1:2])
  sy = u[3] + 0.07 * diff(u[3:4])
  segments(sx, sy, sx + 50000, sy, lwd = 2)
  segments(sx + c(0, 25000, 50000), sy - 1500, sx + c(0, 25000, 50000), sy +
    1500)
  text(sx + c(0, 25000, 50000), sy - 5500, c("0", "25", "50 km"), cex = 0.65)
  par(mar = rep(0, 4))
  plot.new()
  legend("center", legend = c(
    "Jan 2017: Seoul (25)", "Jul 2018: Incheon and Gyeonggi (35)",
    "Jan 2020: additional Gyeonggi (13)", "Never designated (174)"
  ), fill = palette[c(
    "61",
    "79", "97", "0"
  )], border = "#777777", bty = "n", ncol = 2, cex = 0.83)
}

pdf("result/Fig 1.pdf", width = 9, height = 6.2, useDingbats = FALSE)

draw_map()

dev.off()

png("result/Fig 1.png", width = 9, height = 6.2, units = "in", res = 320)

draw_map()

dev.off()

write.csv(st_drop_geometry(geo)[c("id", "province", "district", "g")], "result/_checks/Fig 1 cohort mapping.csv",
  row.names = FALSE, fileEncoding = "UTF-8"
)
