#' Plot Area-Proportional Euler Diagrams
#'
#' Plot Euler diagrams with trellis graphics from \pkg{lattice}. This function
#' calls [lattice::xyplot()] under the hood, allowing plots of
#' both individual euler diagrams as well as grids of diagrams
#' in case the `by` argument was used in the call to [euler()].
#'
#' Almost all of the relevant functionality for [lattice::xyplot()] is
#' available here. For instance, providing specifications to
#' `par.settings` will have an effect on many aspects of the plot. Moreover,
#' arguments that are given here will trickle down to the panel function
#' [panel.euler()] and subsequently to [panel.euler.circles()] and
#' [panel.euler.labels()], which do the actual plotting.
#'
#' The default value for `fill` causes, \pkg{eulerr} to choose color palettes
#' based on the number of sets, trying to provide palettes adapted to color
#' vision deficiencies based on [qualpalr::qualpal()].
#'
#' @param x An object of class `euler`.
#' @param fill Fill color. Either a function that takes as its first argument
#'   the number of colors to generate, or a sequence of colors.
#' @param fill_alpha Alpha for the fill.
#' @param auto.key Plot a legend for the sets.
#' @param counts Plot counts.
#' @param labels A list or character vector of labels.
#' @param fontface Fontface for the labels. (See [grid::gpar()]).
#' @param default.scales Default scales. Turns off
#' @param panel The panel function. Should usually be left untouched.
#' @param par.settings Graphical parameters for trellis displays. See
#'   [lattice::trellis.par.get()].
#' @param default.prepanel Default prepanel function. Should usually be left
#'   untouched.
#' @param ... Arguments to pass down to [panel.euler()], which in turn passes
#'   them down to [panel.euler.circles()] and [panel.euler.labels()].
#' @param outer_strips Deprecated
#' @param fill_opacity Deprecated
#'
#' @inherit lattice::levelplot return
#'
#' @export
#'
#' @seealso [panel.euler.circles()], [panel.euler.labels()],
#'   [lattice::xyplot()], [grid::gpar()], [grid::grid.circle()],
#'   [lattice::panel.xyplot()], [euler()], [qualpalr::qualpal()]
#'
#' @examples
#' fit <- euler(c("A" = 10, "B" = 5, "A&B" = 3))
#' plot(fit, labels = c("foo", "bar"), fill_alpha = 0.7)
#'
#' # Customize colors, remove borders, bump alpha, color labels white
#' plot(fit,
#'      fill_alpha = 0.5,
#'      fill = c("red", "steelblue4"),
#'      col = "white",
#'      border = "transparent",
#'      fontface = "bold.italic")
#'
#' # Add counts to the plot
#' plot(fit, counts = TRUE)
#'
#' # Add a custom legend and retain counts
#' plot(fit, counts = TRUE, auto.key = list(space = "bottom", columns = 2))
#'
#' # Plot without fills and distinguish sets with border types instead
#' plot(fit, lty = c("solid", "dotted"), fill = "transparent", cex = 2,
#'      fontface = 2, labels = c("foo", "bar"))
#'
#' # Plot a grid of euler plots
#' dat <- data.frame(
#'   A      = sample(c(TRUE, FALSE), size = 100, replace = TRUE),
#'   B      = sample(c(TRUE, TRUE, FALSE), size = 100, replace = TRUE),
#'   gender = sample(c("Men", "Women"), size = 100, replace = TRUE),
#'   nation = sample(c("Sweden", "Denmark"), size = 100, replace = TRUE)
#' )
#'
#' gridfit <- euler(dat[, 1:2], by = dat[, 3:4])
#' plot(gridfit, auto.key = TRUE)
#'
#' # We can modify the grid layout as well
#' plot(gridfit, layout = c(1, 4))
plot.euler <- function(
  x,
  fill = qualpalr_pal,
  fill_alpha = 0.4,
  auto.key = FALSE,
  counts = FALSE,
  labels = is.logical(auto.key) && !isTRUE(auto.key),
  fontface = "bold",
  par.settings = list(),
  ...,
  default.prepanel = prepanel.euler,
  default.scales = list(draw = FALSE),
  panel = panel.euler,
  outer_strips,
  fill_opacity
) {
  assert_that(is.number(fill_alpha),
              is.flag(auto.key) || is.list(auto.key),
              is.flag(counts) || is.list(counts),
              is.list(par.settings))

  if (!missing(fill_opacity))
    fill_alpha <- fill_opacity

  if (!missing(outer_strips)) {
    warning("'outer_strips' is deprecated; try latticeExtra::useOuterStrips() for the same functionality.")
  }

  is_by <- inherits(x, "by")

  if (is.function(fill))
    fill <- fill(if (is_by) nrow(x[[1]]$coefficients) else nrow(x$coefficients))

  fill <- adjustcolor(fill, fill_alpha)

  if (is_by) {
    dd <- do.call(rbind, lapply(x, "[[", "coefficients"))
    orig <- do.call(cbind, lapply(x, "[[", "original.values"))
    fitted <- do.call(cbind, lapply(x, "[[", "fitted.values"))
    if (isTRUE(labels))
      labels <- rownames(x[[1]]$coefficients)
    else if (is.logical(labels))
      labels <- NULL
  } else {
    dd <- x$coefficients
    orig <- x$original.values
    fitted <- x$fitted.values
    if (isTRUE(labels))
      labels <- rownames(x$coefficients)
    else if (is.logical(labels))
      labels <- NULL
    par.settings <- update_list(par.settings, list(
      axis.line = list(col = "transparent")
    ))
  }

  par.settings <- update_list(par.settings,
                              list(superpose.polygon = list(col = fill)))

  if (isTRUE(auto.key) || is.list(auto.key)) {
    auto.key <- update_list(list(
      rectangles = TRUE, points = FALSE
    ), if (is.list(auto.key)) auto.key else list())
  } else {
    auto.key <- FALSE
  }

  setnames <- factor(rownames(dd))
  rownames(dd) <- NULL
  dd <- as.data.frame(dd)
  dd$set <- setnames

  if (is_by) {
    d <- dim(x)
    dn <- dimnames(x)
    n <- NROW(coef(x[[1]]))

    factors <- lapply(dn, as.factor)
    levels <- names(factors)
    factors <- expand.grid(factors)
    factors <- factors[rep(seq_len(NROW(factors)), each = n), , drop = FALSE]
    rownames(factors) <- NULL
    dd <- cbind(dd, factors)
  } else {
    levels <- NULL
  }

  # Retrieve call
  ccall <- match.call()
  ocall <- sys.call(sys.parent())
  ocall[[1]] <- quote(eulerplot)

  # Update call
  ccall$x <- as.formula(
    paste("y ~ x",
          if (is_by) paste("|", paste(levels, collapse = " + ")) else "")
  )
  ccall$r <- dd$r
  ccall$data <- dd
  ccall$groups <- quote(set)
  ccall$panel <- panel
  ccall$default.prepanel <- default.prepanel
  ccall$counts <- counts
  ccall$aspect <- "iso"
  ccall$labels <- labels
  ccall$original.values <- orig
  ccall$fitted.values <- fitted
  ccall$fontface <- fontface
  ccall$default.scales <- default.scales
  ccall$par.settings <- par.settings
  ccall$xlab <- ""
  ccall$ylab <- ""
  ccall$auto.key <- auto.key
  ccall$fill <- fill

  # Make the call
  ccall[[1]] <- quote(lattice::xyplot)
  ans <- eval.parent(ccall)
  ans$call <- ocall
  ans
}

#' Prepanel Function for Euler Diagrams
#'
#' @inheritParams panel.euler
#' @param ... Ignored.
#'
#' @return A list of `xlim` and `ylim` items.
#' @export
prepanel.euler <- function(x, y, r, subscripts, ...) {
  r <- r[subscripts]
  list(xlim = range(x + r, x - r),
       ylim = range(y + r, y - r))
}

#' Panel Function for Euler Diagrams
#'
#' @param x X coordinates for the circle centers.
#' @param y Y coordinates for the circle centers.
#' @param r Radii.
#' @param subscripts A vector of subscripts (See [lattice::xyplot()]).
#' @param fill Fill color for circles. (See [grid::gpar()].)
#' @param lty Line type for circles. (See [grid::gpar()].)
#' @param lwd Line weight for circles. (See [grid::gpar()].)
#' @param border Border color for circles.
#' @param alpha Alpha for circles. Note that [plot.euler()] by default
#'   modifies the alpha of `col` instead to avoid affecting the alpha of
#'   the borders. (See [grid::gpar()].)
#' @param fontface Fontface for the labels.  (See [grid::gpar()].)
#' @param counts Plots the original values for the disjoint set combinations
#'   (`original.values`). Can also be a list, in which the contents of the list
#'   will be passed on to [lattice::panel.text()] to modify the appearance of
#'   the counts.
#' @param labels Labels to plot on the circles.
#' @param original.values Original values for the disjoint set combinations.
#' @param fitted.values Fitted values for the disjoint set combinations.
#' @param ... Passed down to [panel.euler.circles()] and [panel.euler.labels()].
#'
#' @seealso [grid::gpar()].
#'
#' @return Plots euler diagrams inside a trellis panel.
#'
#' @export
panel.euler <- function(
  x,
  y,
  r,
  subscripts,
  fill = superpose.polygon$col,
  lty = superpose.polygon$lty,
  lwd = superpose.polygon$lwd,
  border = superpose.polygon$border,
  alpha = superpose.polygon$alpha,
  fontface = "bold",
  counts = TRUE,
  labels = NULL,
  original.values,
  fitted.values,
  ...
) {
  superpose.polygon <- trellis.par.get("superpose.polygon")

  assert_that(is.numeric(x),
              is.numeric(y),
              is.numeric(r),
              is.flag(counts) || is.list(counts))

  if (is.matrix(original.values)) {
    original.values <- original.values[, packet.number()]
    fitted.values <- fitted.values[, packet.number()]
  }

  panel.euler.circles(x = x,
                      y = y,
                      r = r[subscripts],
                      fill = fill,
                      lty = lty,
                      lwd = lwd,
                      border = border,
                      identifier = "euler",
                      ...)

  if ((is.list(counts) || isTRUE(counts)) || !is.null(labels)) {
    panel.euler.labels(x = x,
                       y = y,
                       r = r[subscripts],
                       labels = labels,
                       counts = counts,
                       original.values = original.values,
                       fitted.values = fitted.values,
                       fontface = fontface,
                       ...)
  }
}

#' Panel Function for Circles
#'
#' @inheritParams panel.euler
#' @param border Border color.
#' @param fill Circle fill.
#' @param ... Passed on to [grid::grid.circle()].
#' @param col Ignored
#' @param font Ignored
#' @param fontface Ignored
#' @param identifier A character string that is prepended to the name of the
#'   grob that is created.
#' @param name.type A character value indicating whether the name of the grob
#'   should have panel or strip information added to it. Typically either
#'   `"panel"`, `"strip"`, `"strip.left"`, or `""` (for no extra information).
#'
#' @seealso [grid::grid.circle()].
#'
#' @return Plots circles inside a trellis panel.
#' @export
panel.euler.circles <- function(
  x,
  y,
  r,
  border = "black",
  fill = "transparent",
  ...,
  identifier = NULL,
  name.type = "panel",
  col,
  font,
  fontface
) {
  if (sum(!is.na(x)) < 1)
    return()

  border <- if (all(is.na(border)))
    "transparent"
  else if (is.logical(border))
    if (border) "black" else "transparent"
  else
    border

  if (hasGroupNumber())
    group <- list(...)$group.number
  else
    group <- 0

  xy <- xy.coords(x, y, recycle = TRUE)
  grid.circle(
    x = xy$x,
    y = xy$y,
    r = r,
    default.units = "native",
    gp = gpar(fill = fill, col = border, ...),
    name = primName("circles", identifier, name.type, group)
  )
}

#' Panel Function for Circle Labels
#'
#' @inheritParams panel.euler
#' @param ... Arguments passed on to [panel.text()]
#'
#' @return Computes and plots labels or counts inside the centers of the
#'   circles' overlaps.
#' @export
panel.euler.labels <- function(
    x,
    y,
    r,
    labels,
    counts = TRUE,
    original.values,
    fitted.values,
    ...
) {
  n <- length(x)
  id <- bit_indexr(n)
  singles <- rowSums(id) == 1L

  do_counts <- isTRUE(counts) || is.list(counts)
  do_labels <- !is.null(labels)

  centers <- locate_centers(x = x,
                            y = y,
                            r = r,
                            original.values = original.values,
                            fitted.values = fitted.values)

  # Plot counts
  if (do_counts) {
    do.call(panel.text, update_list(list(
      x = centers$x[singles],
      y = centers$y[singles],
      labels = centers$n[singles],
      identifier = "counts",
      offset = if (do_labels) 0.25 else NULL,
      pos = if (do_labels) 1 else NULL
    ), if (is.list(counts)) counts else list()))

    do.call(panel.text, update_list(list(
      x = centers$x[!singles],
      y = centers$y[!singles],
      labels = centers$n[!singles],
      identifier = "counts"
    ), if (is.list(counts)) counts else list()))
  }

  # Plot labels
  if (do_labels)
    do.call(panel.text, update_list(list(
      centers$x[singles],
      centers$y[singles],
      labels,
      offset = 0.25,
      pos = if (do_counts) 3L else NULL,
      identifier = "labels",
      name.type = "panel"
    ), list(...)))
}


#' Locate Centers of Circle Overlaps
#'
#' @inheritParams panel.euler
#'
#' @return A data frame with centers of the circle overlaps and their
#'   respective original counts.
#' @keywords internal
locate_centers <- function(x, y, r, original.values, fitted.values) {
  n <- length(x)

  if (n > 1L) {
    n_samples <- 500L
    seqn  <- seq.int(0L, n_samples - 1L, 1L)
    theta <- seqn * pi * (3L - sqrt(5L))
    rad   <- sqrt(seqn / n_samples)
    px    <- rad * cos(theta)
    py    <- rad * sin(theta)

    id <- bit_indexr(n)
    n_combos <- nrow(id)

    # In case the user asks for counts, compute locations for these
    xx <- yy <- rep.int(NA_real_, nrow(id))

    not_zero <- fitted.values > .Machine$double.eps ^ 0.25

    singles <- rowSums(id) == 1L

    for (i in seq_along(r)) {
      x0 <- px * r[i] + x[i]
      y0 <- py * r[i] + y[i]
      in_which <- find_surrounding_sets(x0, y0, x, y, r)

      for (j in seq_len(nrow(id))[id[, i]]) {
        idj <- id[j, ]
        if (all(is.na(xx[j]), idj[i])) {
          if (singles[j]) {
            sums <- colSums(in_which)
            locs <- sums == min(sums)
          } else {
            locs <- colSums(in_which == idj) == nrow(in_which)
          }

          if (any(locs)) {
            x1 <- x0[locs]
            y1 <- y0[locs]
            dists <- mapply(dist_point_circle, x = x1, y = y1,
                            MoreArgs = list(h = x, k = y, r = r),
                            SIMPLIFY = FALSE, USE.NAMES = FALSE)
            dists <- do.call(cbind, dists)
            labmax <- max_colmins(dists)
            xx[j] <- x1[labmax]
            yy[j] <- y1[labmax]
          }
        }
      }
    }
  } else {
    # One circle, always placed in the middle
    xx <- yy <- 0L
    singles <- TRUE
    n_combos <- 1L
  }

  data.frame(x = xx, y = yy, n = original.values)
}
