# Helper functions for the Journal Checker Tool (JCT)
# "Transformative Agreements Public Data" (CC0).
# Source: https://journalcheckertool.org/transformative-agreements/
#
# These helpers are deliberately small and dependency-light so that a
# non-developer can read them top to bottom.

suppressPackageStartupMessages(library(readr))

# Published Google Sheet (as CSV) that lists every transformative agreement.
jct_index_url <- function() {
  paste0(
    "https://docs.google.com/spreadsheets/d/e/",
    "2PACX-1vStezELi7qnKcyE8OiO2OYx2kqQDOnNsDX1JfAsK487n2uB_Dve5iDTwhUFfJ7eFPDhEjkfhXhqVTGw",
    "/pub?gid=1130349201&single=true&output=csv"
  )
}

jct_index_column_types <- function() {
  cols(
    "ESAC ID" = col_character(),
    "Relationship" = col_character(),
    "C/A Only" = col_character(),
    "Data URL" = col_character(),
    "End Date" = col_date(),
    "Last Reviewed" = col_date()
  )
}

# Read the agreement index. One row per agreement x relationship (sub-package);
# each row points to its own "Data URL".
jct_index_reader <- function() {
  read_csv(url(jct_index_url()), col_types = jct_index_column_types())
}

# Read a single agreement data file. Returns NULL on a network/parse error so
# that one bad URL never aborts the whole run (the guard rail in fetch.R catches
# systematic, large-scale failures instead).
jct_agreement_reader <- function(data_url) {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)

  tryCatch(
    {
      old_timeout <- getOption("timeout")
      on.exit(options(timeout = old_timeout), add = TRUE)
      options(timeout = max(60, old_timeout))
      download.file(data_url, tmp, quiet = TRUE, mode = "wb")
      suppressWarnings(read_csv(tmp, col_types = cols(.default = col_character())))
    },
    error = function(e) {
      message("  could not read: ", data_url)
      NULL
    }
  )
}

# An agreement data file has two stacked blocks of columns:
#   columns 1-5  -> the journals covered
#   columns 6-9  -> the participating institutions (incl. "ROR ID")
jct_agreement_journals <- function(df) {
  j <- df[, 1:5]
  j[!is.na(j[[1]]), , drop = FALSE]
}

jct_agreement_institutions <- function(df) {
  i <- df[, 6:9]
  i[!is.na(i[[1]]), , drop = FALSE]
}

# Normalise a ROR identifier to its bare lowercase id, e.g.
# "https://ror.org/042AQKY30" -> "042aqky30".
ror_bare <- function(x) {
  x <- tolower(trimws(x))
  sub("^https?://ror\\.org/", "", x)
}

# Read the institution configuration (name, ror_id, slug) and add a bare ROR id.
read_orgs <- function(path = "data-raw/orgs.csv") {
  orgs <- read_csv(path, col_types = cols(.default = col_character()))
  orgs$ror_bare <- ror_bare(orgs$ror_id)
  orgs
}

# Does a semicolon-separated members string contain a given slug?
has_member <- function(members, slug) {
  grepl(paste0("(^|;)", slug, "(;|$)"), members)
}
