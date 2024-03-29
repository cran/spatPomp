##' pStop
##'
##' Custom error function
##' @name pStop
##' @keywords internal
##'
##' @param fn name of function (will be enclosed in single quotes)
##' @param \dots message
##' @return No return value as this is simply a custom error function.
##'
pStop <- function (fn, ...) {
  fn <- as.character(fn)
  stop("in ",sQuote(fn[1L]),": ",...,call.=FALSE)
}

##' @rdname pStop
pStop_ <- function (...) {
  stop(...,call.=FALSE)
}

##' @rdname pStop
pWarn <- function (fn, ...) {
  fn <- as.character(fn)
  warning("in ",sQuote(fn[1L]),": ",...,call.=FALSE)
}

##' @rdname pStop
pWarn_ <- function (...) {
  warning(...,call.=FALSE)
}

undef_method <- function (method, object) {
  o <- deparse(substitute(object))
  pStop_(sQuote(method)," is undefined for ",sQuote(o)," of class ",
         sQuote(class(object)),".")
}

reqd_arg <- function (method, object) {
  if (is.null(method) || length(method)==0)
    pStop_(sQuote(object)," is a required argument.")
  else
    pStop(method,sQuote(object)," is a required argument.")
}

invalid_names <- function (names) {
  is.null(names) || !all(nzchar(names)) || any(is.na(names)) || anyDuplicated(names)
}
