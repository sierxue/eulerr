#' Tally Set Relationships
#'
#' @param sets A data.frame with set relationships and weights.
#'
#' @return Calls [euler()] after the set relationships have been coerced to a
#'   named numeric vector.
#' @keywords internal
tally_combinations <- function(sets) {
  weights <- sets$weights
  sets <- sets[, !(colnames(sets) == "weights")]
  if (!is.matrix(sets))
    sets <- as.matrix(sets)

  id <- bit_indexr(ncol(sets))
  tally <- double(nrow(id))

  for (i in 1:nrow(id)) {
    tally[i] <-
      sum(as.numeric(colSums(t(sets) == id[i, ]) == ncol(sets)) * weights)
    names(tally)[i] <- paste0(colnames(sets)[id[i, ]], collapse = "&")
  }

  euler(tally)
}

#' Rescale Values to a New Range
#'
#' @param x Numeric vector
#' @param new_min New min
#' @param new_max New max
#'
#' @return Rescaled vector
#' @keywords internal
rescale <- function(x, new_min, new_max) {
  (new_max - new_min) / (max(x) - min(x)) * (x - max(x)) + new_max
}

#' Center Circles
#'
#' @param pars A matrix or data.frame of x coordinates, y coordinates, and
#'   radii.
#'
#' @return A centered version of `pars`.
#' @keywords internal
center_circles <- function(pars) {
  x <- pars[, 1L]
  y <- pars[, 2L]
  r <- pars[, 3L]
  xlim <- range(c(x + r, x - r))
  ylim <- range(c(y + r, y - r))
  pars[, 1L] <- x + abs(xlim[1L] - xlim[2L]) / 2L - xlim[2L]
  pars[, 2L] <- y + abs(ylim[1L] - ylim[2L]) / 2L - ylim[2L]
  pars
}

#' Update a List with User Input
#'
#' Wrapper for [utils::modifyList()].
#'
#' @param x A list to be updated.
#' @param val Stuff to update `x` with.
#'
#' @seealso [utils::modifyList()]
#' @return Returns an updated list.
#' @keywords internal
update_list <- function(x, val) {
  if (is.null(x))
    x <- list()
  if (!is.list(val))
    tryCatch(val <- as.list(val))
  if (!is.list(x))
    tryCatch(x <- as.list(x))
  modifyList(x, val)
}

#' Suppress Plotting
#'
#' @param x Object to call [graphics::plot()] on.
#' @param ... Arguments to pass to `x`.
#'
#' @return Invisibly returns whatever `plot(x)` would normally returns, but
#'   does not plot anything (which is the point).
#' @keywords internal
dont_plot <- function(x, ...) {
  tmp <- tempfile()
  png(tmp)
  p <- plot(x, ...)
  dev.off()
  unlink(tmp)
  invisible(p)
}

#' Suppress Printing
#'
#' @param x Object to (not) print.
#' @param ... Arguments to `x`.
#'
#' @return Nothing, which is the point.
#' @keywords internal
dont_print <- function(x, ...) {
  capture.output(y <- print(x, ...))
  invisible(y)
}

# Set up qualitative color palette ----------------------------------------

#' Set up a Qualitative Color Palette
#'
#' Uses a custom color palette generated from [qualpalr::qualpal()],
#' which tries to provide distinct color palettes adapted to color vision
#' deficiency.
#'
#' @param n Number of Colors to Generate
#'
#' @return A string of hex colors
#' @keywords internal
qualpalr_pal <- function(n) {
  palettes[[n]]
}

#' Check If Object Is Strictly FALSE
#'
#' @param x Object to check.
#'
#' @return Logical.
#' @keywords internal
is_false <- function(x) {
  is.logical(x) && !isTRUE(x)
}
