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
    config(displayModeBar = FALSE, responsive = TRUE)
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
