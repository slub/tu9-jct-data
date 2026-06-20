# Shared helpers for the Quarto website. All chunks run from the project root
# (see `execute-dir: project` in _quarto.yml), so paths are given relative to it.

suppressPackageStartupMessages({
  library(readr)
  library(reactable)
  library(htmltools)
})

read_data <- function(...) {
  read_csv(file.path("data", ...), col_types = cols(.default = col_character()))
}

read_meta <- function() {
  jsonlite::read_json("data/meta.json", simplifyVector = FALSE)
}

# ESAC registry enrichment (id -> name, publisher, ...), built by scripts/esac.R.
# Read once and left-joined onto any data frame that carries an `esac_id` column.
esac_lookup <- local({
  path <- file.path("data", "esac.csv")
  if (file.exists(path)) {
    read_csv(path, col_types = cols(.default = col_character()))
  } else {
    data.frame(id = character(), name = character(), publisher = character(),
               stringsAsFactors = FALSE)
  }
})

# Add `name` and `publisher` columns by matching `esac_id` against the registry.
# Rows without a registry match get NA (rendered as a blank cell).
with_esac <- function(df) {
  m <- match(df$esac_id, esac_lookup$id)
  df$name      <- esac_lookup$name[m]
  df$publisher <- esac_lookup$publisher[m]
  df
}

# Link an ESAC ID to its page in the public ESAC registry.
esac_cell <- function(value) {
  if (is.na(value) || value == "") return("")
  url <- paste0(
    "https://esac-initiative.org/about/transformative-agreements/",
    "agreement-registry/", value, "/")
  as.character(tags$a(href = url, target = "_blank", value))
}

# Link an ISSN to its record in the ISSN Portal.
issn_cell <- function(value) {
  if (is.na(value) || value == "") return("")
  url <- paste0("https://portal.issn.org/resource/ISSN/", value)
  as.character(tags$a(href = url, target = "_blank", value))
}

# Render a URL cell as a short link.
# The agreement data URLs are published Google Sheets exported as CSV. Drop the
# CSV export parameters so the link opens the readable (HTML) sheet view.
sheet_cell <- function(label = "Google Sheets") {
  function(value) {
    if (is.na(value) || value == "") return("")
    html_url <- sub("&single=true&output=csv", "", value, fixed = TRUE)
    as.character(tags$a(href = html_url, target = "_blank", label))
  }
}

# Show semicolon-separated member slugs as small badges.
members_cell <- function(value) {
  if (is.na(value) || value == "") return("")
  slugs <- strsplit(value, ";", fixed = TRUE)[[1]]
  paste(slugs, collapse = ", ")
}

agreements_table <- function(df) {
  df <- with_esac(df)
  reactable(
    df[, c("name", "esac_id", "publisher", "relationship",
           "end_date", "members", "data_url")],
    searchable = TRUE, filterable = TRUE, sortable = TRUE,
    defaultPageSize = 25, showPageSizeOptions = TRUE, highlight = TRUE,
    columns = list(
      name          = colDef(name = "Agreement", minWidth = 170),
      esac_id       = colDef(name = "ESAC ID", cell = esac_cell, html = TRUE, minWidth = 130),
      publisher     = colDef(name = "Publisher", minWidth = 150),
      relationship  = colDef(name = "Relationship"),
      end_date      = colDef(name = "End date", minWidth = 90),
      members       = colDef(name = "TU9 members", cell = members_cell),
      data_url      = colDef(name = "Source", cell = sheet_cell(), html = TRUE, minWidth = 110)
    )
  )
}

journals_table <- function(df) {
  df <- with_esac(df)
  reactable(
    df[, c("title", "eissn", "pissn", "name", "esac_id", "url", "members")],
    searchable = TRUE, filterable = TRUE, sortable = TRUE,
    defaultPageSize = 25, showPageSizeOptions = TRUE, highlight = TRUE,
    columns = list(
      title   = colDef(name = "Journal", minWidth = 220),
      eissn   = colDef(name = "ISSN (online)", cell = issn_cell, html = TRUE, minWidth = 110),
      pissn   = colDef(name = "ISSN (print)", cell = issn_cell, html = TRUE, minWidth = 110),
      name    = colDef(name = "Agreement", minWidth = 150),
      esac_id = colDef(name = "ESAC ID", cell = esac_cell, html = TRUE, minWidth = 130),
      url     = colDef(name = "Source", cell = sheet_cell(), html = TRUE, minWidth = 110),
      members = colDef(name = "TU9 members", cell = members_cell)
    )
  )
}

# Full body of a per-institution page. `url` is the institution's own page on
# open-access agreements and funding support (from data-raw/urls.csv, passed in
# by gen_pages.R); when absent the intro paragraph is omitted.
inst_page <- function(slug, url = NULL) {
  a <- read_data(slug, "agreements.csv")
  j <- read_data(slug, "journals.csv")
  repo <- sprintf("https://github.com/slub/tu9-jct-data/blob/main/data/%s", slug)
  intro <- if (!is.null(url) && !is.na(url) && nzchar(url)) {
    tags$p(
      "The library provides further details on its ",
      tags$a(href = url, target = "_blank",
             "open-access agreements and funding support"),
      ".")
  }
  tagList(
    intro,
    tags$p(
      "Download this institution's data as CSV: ",
      tags$a(href = paste0(repo, "/agreements.csv"), target = "_blank", "agreements.csv"),
      " · ",
      tags$a(href = paste0(repo, "/journals.csv"), target = "_blank", "journals.csv"),
      "."),
    tags$h2(sprintf("Agreements (%d)", nrow(a))),
    agreements_table(a),
    tags$h2(sprintf("Journals (%d unique)", nrow(unique(j[c("title", "eissn", "pissn")])))),
    journals_table(j)
  )
}
