#!/usr/bin/env Rscript
# Fetch transformative-agreement metadata for the TU9 universities from the
# Journal Checker Tool and write the data views:
#
#   data/agreements.csv          all agreements with >=1 TU9 institution
#   data/journals.csv            all journals covered by those agreements
#   data/<slug>/agreements.csv   one institution's agreements
#   data/<slug>/journals.csv     journals covered by one institution's agreements
#   data/meta.json               summary counts + last-updated date (for the site)
#
# Matching is strict: an institution "participates" only if its exact ROR id
# (from data-raw/orgs.csv) appears in an agreement sub-package. Precision first.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

source("scripts/jct.R")

# --- configuration ---------------------------------------------------------
GUARD_THRESHOLD <- 0.20  # abort if the agreement count drops by more than this
force <- nzchar(Sys.getenv("FORCE"))

orgs <- read_orgs()
ror_to_slug <- setNames(orgs$slug, orgs$ror_bare)

# --- collect ---------------------------------------------------------------
message("Reading JCT agreement index ...")
idx <- jct_index_reader()
idx <- idx[!is.na(idx$`Data URL`), ]
urls <- unique(idx$`Data URL`)
message("Agreement data files to inspect: ", length(urls))

agreement_rows <- list()
journal_rows <- list()

for (k in seq_along(urls)) {
  data_url <- urls[k]
  df <- jct_agreement_reader(data_url)
  if (is.null(df) || ncol(df) < 9) next

  inst <- jct_agreement_institutions(df)
  hit_rors <- ror_bare(inst$`ROR ID`)
  members <- sort(unique(ror_to_slug[hit_rors[hit_rors %in% names(ror_to_slug)]]))
  if (length(members) == 0) next            # no TU9 institution -> skip
  members_str <- paste(members, collapse = ";")

  meta <- idx[idx$`Data URL` == data_url, ][1, ]
  agreement_rows[[length(agreement_rows) + 1L]] <- tibble(
    esac_id       = meta$`ESAC ID`,
    relationship  = meta$Relationship,
    end_date      = as.character(meta$`End Date`),
    last_reviewed = as.character(meta$`Last Reviewed`),
    data_url      = data_url,
    members       = members_str
  )

  jr <- jct_agreement_journals(df)
  if (nrow(jr) > 0) {
    journal_rows[[length(journal_rows) + 1L]] <- tibble(
      title   = jr$`Journal Name`,
      eissn   = jr$`ISSN (Online)`,
      pissn   = jr$`ISSN (Print)`,
      esac_id  = meta$`ESAC ID`,
      data_url = data_url,
      members  = members_str
    )
  }
  if (k %% 50 == 0) message("  ... inspected ", k, "/", length(urls))
}

agreements <- bind_rows(agreement_rows) %>%
  distinct() %>%
  arrange(esac_id, relationship)

journals <- bind_rows(journal_rows) %>%
  distinct() %>%
  arrange(esac_id, title)

message("Found ", nrow(agreements), " agreement rows and ",
        nrow(journals), " journal rows for TU9.")

# --- guard rail ------------------------------------------------------------
existing <- "data/agreements.csv"
if (file.exists(existing) && !force) {
  old_n <- nrow(read_csv(existing, col_types = cols(.default = col_character())))
  new_n <- nrow(agreements)
  if (old_n > 0 && new_n < old_n * (1 - GUARD_THRESHOLD)) {
    stop(sprintf(
      paste0("Guard rail tripped: agreement count fell from %d to %d (more than %.0f%%). ",
             "Refusing to overwrite published data. Re-run with FORCE=1 to override."),
      old_n, new_n, GUARD_THRESHOLD * 100))
  }
}

# --- write -----------------------------------------------------------------
dir.create("data", showWarnings = FALSE)
write_csv(agreements, "data/agreements.csv", na = "")
write_csv(journals,   "data/journals.csv",   na = "")

n_unique_journals <- function(j) nrow(distinct(j, title, eissn, pissn))

# One entry per institution. A slug may map to several ROR ids (e.g. a
# university plus its library); the first row for a slug supplies the name.
institutions <- orgs[!duplicated(orgs$slug), c("name", "slug")]

inst_summary <- vector("list", nrow(institutions))
for (i in seq_len(nrow(institutions))) {
  slug <- institutions$slug[i]
  out_dir <- file.path("data", slug)
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  a_i <- agreements[has_member(agreements$members, slug), ]
  j_i <- journals[has_member(journals$members, slug), ]
  write_csv(a_i, file.path(out_dir, "agreements.csv"), na = "")
  write_csv(j_i, file.path(out_dir, "journals.csv"),   na = "")

  inst_summary[[i]] <- list(
    name = institutions$name[i], slug = slug,
    ror_id = paste(orgs$ror_id[orgs$slug == slug], collapse = ";"),
    n_agreements = nrow(a_i), n_journals = n_unique_journals(j_i)
  )
}

meta <- list(
  updated      = format(Sys.time(), "%Y-%m-%d", tz = "UTC"),
  source       = "Journal Checker Tool - Transformative Agreements Public Data (CC0)",
  n_agreements = nrow(agreements),
  n_journals   = n_unique_journals(journals),
  institutions = inst_summary
)
jsonlite::write_json(meta, "data/meta.json", auto_unbox = TRUE, pretty = TRUE)

message("Done.")
