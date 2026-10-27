# dashboard_helpers.R
# Colours, number formats and chart builders shared by the dashboard pages.
# Sourced by index.qmd.

suppressPackageStartupMessages({
  library(dplyr)
  library(plotly)
  library(htmltools)
})

# Colours ------------------------------------------------------------------------
# One accent colour for the series a chart is about; neutral greys for context.
# Checked with the dataviz palette validator: accent 4.3:1 and context grey
# 7.7:1 against the chart surface; CVD separation between them 21.3.

viz <- list(
  surface   = "#fcfcfb",
  ink       = "#0b0b0b",
  ink_2     = "#52514e",
  muted     = "#898781",
  grid      = "#e1e0d9",
  axis      = "#c3c2b7",
  accent    = "#2a78d6",
  # Sequential blue ramp (light to dark) for maps
  sequential = c("#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#256abf", "#184f95", "#0d366b")
)

font_stack <- 'system-ui, -apple-system, "Segoe UI", sans-serif'

# Formats ----------------------------------------------------------------------

fmt_num <- function(x, digits = 1) formatC(x, format = "f", digits = digits, big.mark = ",")
# Non-breaking space keeps a number and its unit on the same line
fmt_ugm3 <- function(x, digits = 1) paste0(fmt_num(x, digits), "\u00a0µg/m³")
fmt_pct <- function(x, digits = 1) paste0(fmt_num(x, digits), "%")

# Building blocks ----------------------------------------------------------------

# Wrap a widget with an accessible label and a source line underneath.
chart_card <- function(widget, alt, source) {
  tagList(
    tags$div(role = "figure", `aria-label` = alt, widget),
    tags$p(class = "source-note", source)
  )
}

plotly_defaults <- function(p) {
  p |>
    layout(
      font = list(family = font_stack, color = viz$ink_2, size = 13),
      paper_bgcolor = viz$surface,
      plot_bgcolor = viz$surface,
      margin = list(l = 48, r = 24, t = 16, b = 40),
      hoverlabel = list(bgcolor = "#ffffff", bordercolor = viz$axis, font = list(color = viz$ink))
    ) |>
    config(displayModeBar = FALSE, responsive = TRUE) |>
    # The "basic" plotly.js bundle covers scatter and bar charts and is about a
    # quarter of the full library, so the dashboard loads faster on a phone
    partial_bundle(type = "basic", local = TRUE)
}

# Trend chart: London (accent) against England (grey), with optional labelled
# reference lines. `trends` has columns year, series ("London"/"England"), value.
# `refs` has columns value and label (may be empty).
trend_chart <- function(trends, refs, y_title) {
  colours <- c(London = viz$accent, England = viz$ink_2)
  last <- trends |> group_by(series) |> filter(year == max(year)) |> ungroup()
  y_max <- max(c(trends$value, refs$value), na.rm = TRUE) * 1.15

  p <- plot_ly()
  for (s in c("London", "England")) {
    d <- filter(trends, series == s)
    p <- p |>
      add_trace(
        data = d, x = ~year, y = ~value, name = s,
        type = "scatter", mode = "lines+markers",
        line = list(color = colours[[s]], width = 2),
        marker = list(color = colours[[s]], size = 8, line = list(color = viz$surface, width = 2)),
        hovertemplate = paste0("<b>%{y:.1f}</b> ", s, "<extra></extra>")
      )
  }

  ref_shapes <- lapply(seq_len(nrow(refs)), \(i) list(
    type = "line", xref = "paper", x0 = 0, x1 = 1, y0 = refs$value[i], y1 = refs$value[i],
    line = list(color = viz$muted, width = 1, dash = "dash")
  ))
  # Right-aligned so they sit over the latest years, clear of the earlier peaks
  ref_labels <- lapply(seq_len(nrow(refs)), \(i) list(
    xref = "paper", x = 0.99, xanchor = "right", y = refs$value[i], yanchor = "bottom",
    text = refs$label[i], showarrow = FALSE, font = list(size = 11, color = viz$ink_2),
    bgcolor = viz$surface
  ))
  end_labels <- lapply(seq_len(nrow(last)), \(i) list(
    x = last$year[i], y = last$value[i], xanchor = "left", xshift = 8,
    text = paste0(last$series[i], " ", fmt_num(last$value[i])),
    showarrow = FALSE, font = list(size = 12, color = viz$ink)
  ))

  years <- sort(unique(trends$year))

  plotly_defaults(p) |>
    layout(
      hovermode = "x unified",
      # Right margin holds the end labels so they are not clipped on a phone
      margin = list(l = 48, r = 92, t = 16, b = 40),
      xaxis = list(title = "", tickvals = years[seq(1, length(years), by = 2)],
                   tickformat = "d", showgrid = FALSE, linecolor = viz$axis, ticks = "",
                   range = c(min(years) - 0.3, max(years) + 0.3)),
      yaxis = list(title = y_title, rangemode = "tozero", range = c(0, y_max),
                   gridcolor = viz$grid, zeroline = TRUE, zerolinecolor = viz$axis),
      legend = list(orientation = "h", x = 0, y = 1.08, font = list(color = viz$ink_2)),
      shapes = ref_shapes,
      annotations = c(ref_labels, end_labels)
    )
}

# Ranked horizontal bar chart, one series in the accent colour.
# `d` has columns label and value; sorted so the largest is at the top.
ranked_bar_chart <- function(d, x_title, hover_suffix = "", digits = 2) {
  d <- arrange(d, value)
  plot_ly(
    d, x = ~value, y = ~factor(label, levels = label), type = "bar", orientation = "h",
    marker = list(color = viz$accent),
    hovertemplate = paste0("<b>%{x:.", digits, "f}", hover_suffix, "</b> %{y}<extra></extra>")
  ) |>
    plotly_defaults() |>
    layout(
      bargap = 0.35,
      margin = list(l = 150, r = 24, t = 8, b = 40),
      xaxis = list(title = x_title, gridcolor = viz$grid, zeroline = TRUE, zerolinecolor = viz$axis,
                   rangemode = "tozero"),
      yaxis = list(title = "", tickfont = list(size = 11), tickmode = "linear", dtick = 1)
    )
}

# Scatter of two measures across boroughs, with a hover label per point.
# `d` has columns x, y and label.
scatter_chart <- function(d, x_title, y_title, x_digits = 1, y_digits = 1) {
  plot_ly(
    d, x = ~x, y = ~y, text = ~label, type = "scatter", mode = "markers",
    marker = list(color = viz$accent, size = 10, line = list(color = viz$surface, width = 2)),
    hovertemplate = paste0("<b>%{text}</b><br>", x_title, ": %{x:.", x_digits, "f}<br>",
                           y_title, ": %{y:.", y_digits, "f}<extra></extra>")
  ) |>
    plotly_defaults() |>
    layout(
      xaxis = list(title = x_title, gridcolor = viz$grid, zeroline = FALSE),
      yaxis = list(title = y_title, gridcolor = viz$grid, zeroline = FALSE)
    )
}

# Tornado diagram: bars from the base value to the low and high results.
# `d` has columns input, low_value, high_value, low_label, high_label;
# values in pounds.
tornado_chart <- function(d, base_value, x_title) {
  # Plot in £ millions so the axis reads cleanly
  d <- d |> mutate(low_value = low_value / 1e6, high_value = high_value / 1e6)
  base_value <- base_value / 1e6
  d <- arrange(d, high_value - low_value)
  d$input <- factor(d$input, levels = d$input)
  p <- plot_ly()
  for (side in c("low", "high")) {
    value <- d[[paste0(side, "_value")]]
    label <- d[[paste0(side, "_label")]]
    p <- p |>
      add_trace(
        type = "bar", orientation = "h", y = d$input,
        base = pmin(value, base_value), x = abs(value - base_value),
        marker = list(color = if (side == "low") viz$ink_2 else viz$accent),
        name = if (side == "low") "Lower result" else "Higher result",
        text = label, textposition = "none", customdata = value,
        hovertemplate = "<b>£%{customdata:.1f}m</b> %{text}<extra></extra>"
      )
  }
  plotly_defaults(p) |>
    layout(
      barmode = "overlay", bargap = 0.35,
      margin = list(l = 190, r = 24, t = 8, b = 40),
      xaxis = list(title = x_title, gridcolor = viz$grid, tickprefix = "£", ticksuffix = "m",
                   tickformat = ".0f"),
      yaxis = list(title = ""),
      legend = list(orientation = "h", x = 0, y = 1.08),
      shapes = list(list(type = "line", yref = "paper", y0 = 0, y1 = 1, x0 = base_value, x1 = base_value,
                         line = list(color = viz$ink, width = 1)))
    )
}

# Acceptability curve: share of PSA draws in which a scheme of a given annual
# cost per resident is cost-effective, one line per threshold.
acceptability_chart <- function(d) {
  thresholds <- sort(unique(d$threshold))
  colours <- c(viz$accent, viz$ink_2)
  p <- plot_ly()
  for (i in seq_along(thresholds)) {
    di <- filter(d, threshold == thresholds[i])
    name <- paste0("£", format(thresholds[i], big.mark = ","), " per QALY")
    p <- p |>
      add_trace(
        data = di, x = ~annual_cost_per_resident, y = ~prob_cost_effective * 100,
        type = "scatter", mode = "lines", name = name,
        line = list(color = colours[i], width = 2),
        hovertemplate = paste0("<b>%{y:.0f}%</b> at £%{x:.2f} per resident (", name, ")<extra></extra>")
      )
  }
  plotly_defaults(p) |>
    layout(
      hovermode = "x unified",
      xaxis = list(title = "Annual scheme cost per London resident (£)", gridcolor = viz$grid,
                   tickprefix = "£", zeroline = FALSE),
      yaxis = list(title = "Chance the scheme is cost-effective (%)", range = c(0, 102),
                   gridcolor = viz$grid),
      legend = list(orientation = "h", x = 0, y = 1.1)
    )
}

# Choropleth of a borough measure on a one-hue sequential scale, no tiles.
# `shapes` is an sf object with area_code and area_name; `values` has
# area_code and value.
borough_map <- function(shapes, values, legend_title, digits = 1, note_codes = character()) {
  m <- dplyr::left_join(shapes, values, by = "area_code")
  pal <- leaflet::colorNumeric(viz$sequential, domain = m$value)
  labels <- paste0(
    "<b>", htmltools::htmlEscape(m$area_name), "</b><br>",
    formatC(m$value, format = "f", digits = digits), " µg/m³",
    ifelse(m$area_code %in% note_codes, "<br>Small population: not ranked", "")
  ) |>
    lapply(htmltools::HTML)
  leaflet::leaflet(m, options = leaflet::leafletOptions(zoomSnap = 0.25, attributionControl = FALSE)) |>
    leaflet::addPolygons(
      fillColor = ~pal(value), fillOpacity = 0.9,
      color = viz$surface, weight = 1.5,
      label = labels,
      highlightOptions = leaflet::highlightOptions(weight = 3, color = viz$ink, bringToFront = TRUE)
    ) |>
    leaflet::addLegend("bottomright", pal = pal, values = ~value, title = legend_title, opacity = 0.9,
                       labFormat = leaflet::labelFormat(digits = digits))
}
