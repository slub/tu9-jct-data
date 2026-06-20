#!/usr/bin/env Rscript
# Enrich the TU9 agreements with metadata from the ESAC Transformative
# Agreement (TA) Registry and write:
#
#   data/esac.csv   one row per ESAC ID found in data/agreements.csv, with the
#                   agreement name, publisher, consortium and start/end dates.
#
# The registry is a large xlsx snapshot published by the ESAC initiative behind
# a Keeper share link. That link is ROTATED every time ESAC publishes a new
# snapshot, so this step is deliberately BEST EFFORT: any download/parse error
# (e.g. the URL has 404'd) is non-fatal, the last-good data/esac.csv is kept,
# and we exit 0 so the weekly JCT refresh in fetch.R is never blocked. Bump the
# one-line URL in esac_registry_url() when ESAC releases a new registry.
#
# Run AFTER scripts/fetch.R (it reads the freshly written data/agreements.csv).

suppressPackageStartupMessages({
  library(readr)
})

# --- configuration ---------------------------------------------------------
GUARD_THRESHOLD <- 0.20  # refuse to overwrite if matched rows drop by more than this

# Published ESAC TA Registry snapshot (xlsx, sheet "registry"). Rotated by ESAC
# on each new release; update this line and the date when that happens.
esac_registry_url <- function() {
  "https://keeper.mpdl.mpg.de/f/316f53c457ca4c0f88b8/?dl=1" # first seen: 2026-06-20 (registry updated 2026-06-19)
}

# Link to an agreement's page in the public ESAC registry.
esac_link <- function(esac_id) {
  paste0(
    "https://esac-initiative.org/about/transformative-agreements/",
    "agreement-registry/", esac_id, "/"
  )
}

# Download and read the registry. Returns NULL on any network/parse error so a
# rotated URL never aborts the run (mirrors jct_agreement_reader in jct.R).
esac_registry_reader <- function() {
  tryCatch({
    tf <- tempfile(fileext = ".xlsx")
    on.exit(unlink(tf), add = TRUE)
    utils::download.file(esac_registry_url(), tf, mode = "wb", quiet = TRUE)
    readxl::read_xlsx(tf, sheet = "registry", col_types = "text")
  }, error = function(e) {
    message("  could not read ESAC registry: ", conditionMessage(e))
    NULL
  })
}

# Excel serial date (days since 1900-01-01, with the well-known 2-day offset)
# to an ISO date string. Non-numeric / missing values become NA.
excel_date <- function(x) {
  n <- suppressWarnings(as.integer(x))
  out <- as.Date("1900-01-01") + (n - 2)
  format(out)  # NA stays NA
}

# --- collect ---------------------------------------------------------------
agreements_path <- "data/agreements.csv"
if (!file.exists(agreements_path)) {
  stop("data/agreements.csv not found; run scripts/fetch.R first.")
}
ids <- unique(read_csv(agreements_path, col_types = cols(.default = col_character()))$esac_id)
ids <- ids[!is.na(ids) & nzchar(ids)]
message("Agreements to enrich from ESAC registry: ", length(ids))

message("Reading ESAC TA Registry ...")
reg <- esac_registry_reader()

out_path <- "data/esac.csv"

keep_last_good <- function(reason) {
  if (file.exists(out_path)) {
    message(reason, " Keeping last-good ", out_path, ".")
  } else {
    message(reason, " No existing ", out_path, " to fall back to; writing nothing.")
  }
  quit(save = "no", status = 0)
}

if (is.null(reg)) {
  keep_last_good("ESAC registry could not be fetched/parsed (rotated URL?).")
}

reg_cols <- c(
  id         = "Agreement ID",
  name       = "Agreement labeling",
  publisher  = "Publisher",
  consortium = "Consortia / Institution",
  start_date = "Start date",
  end_date   = "End date"
)
if (!all(reg_cols %in% names(reg))) {
  missing <- reg_cols[!reg_cols %in% names(reg)]
  keep_last_good(sprintf("ESAC registry layout changed (missing: %s).",
                         paste(missing, collapse = ", ")))
}

esac <- reg[reg[["Agreement ID"]] %in% ids, reg_cols]
names(esac) <- names(reg_cols)
esac$start_date <- excel_date(esac$start_date)
esac$end_date   <- excel_date(esac$end_date)
esac <- esac[order(esac$id), ]

matched <- nrow(esac)
unmatched <- setdiff(ids, esac$id)
message("Matched ", matched, " of ", length(ids), " agreements in the registry.")
if (length(unmatched) > 0) {
  message("  not (yet) in registry: ", paste(unmatched, collapse = ", "))
}

# --- guard rail ------------------------------------------------------------
if (file.exists(out_path)) {
  old_n <- nrow(read_csv(out_path, col_types = cols(.default = col_character())))
  if (old_n > 0 && matched < old_n * (1 - GUARD_THRESHOLD)) {
    keep_last_good(sprintf(
      "Guard rail tripped: ESAC matches fell from %d to %d (more than %.0f%%).",
      old_n, matched, GUARD_THRESHOLD * 100))
  }
}

# --- write -----------------------------------------------------------------
write_csv(esac, out_path, na = "")
message("Wrote ", out_path, " (", matched, " rows).")
