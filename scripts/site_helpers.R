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

# Render a URL cell as a short link.
url_cell <- function(label = "open") {
  function(value) if (is.na(value) || value == "") "" else
    as.character(tags$a(href = value, target = "_blank", label))
}

# Show semicolon-separated member slugs as small badges.
members_cell <- function(value) {
  if (is.na(value) || value == "") return("")
  slugs <- strsplit(value, ";", fixed = TRUE)[[1]]
  paste(slugs, collapse = ", ")
}

agreements_table <- function(df) {
  reactable(
    df,
    searchable = TRUE, filterable = TRUE, sortable = TRUE,
    defaultPageSize = 25, showPageSizeOptions = TRUE, highlight = TRUE,
    columns = list(
      esac_id       = colDef(name = "ESAC ID", minWidth = 130),
      relationship  = colDef(name = "Relationship"),
      end_date      = colDef(name = "End date", minWidth = 90),
      last_reviewed = colDef(name = "Last reviewed", minWidth = 100),
      members       = colDef(name = "TU9 members", cell = members_cell),
      data_url      = colDef(name = "Data", cell = url_cell("CSV"), html = TRUE, minWidth = 60)
    )
  )
}

journals_table <- function(df) {
  reactable(
    df,
    searchable = TRUE, filterable = TRUE, sortable = TRUE,
    defaultPageSize = 25, showPageSizeOptions = TRUE, highlight = TRUE,
    columns = list(
      title   = colDef(name = "Journal", minWidth = 220),
      eissn   = colDef(name = "ISSN (online)", minWidth = 110),
      pissn   = colDef(name = "ISSN (print)", minWidth = 110),
      esac_id = colDef(name = "ESAC ID", minWidth = 130),
      url     = colDef(name = "Data", cell = url_cell("CSV"), html = TRUE, minWidth = 60),
      members = colDef(name = "TU9 members", cell = members_cell)
    )
  )
}

# Full body of a per-institution page.
inst_page <- function(slug) {
  a <- read_data(slug, "agreements.csv")
  j <- read_data(slug, "journals.csv")
  tagList(
    tags$p(tags$a(href = "../data/", "Download this institution's CSV files"),
           " from the repository."),
    tags$h2(sprintf("Agreements (%d)", nrow(a))),
    agreements_table(a),
    tags$h2(sprintf("Journals (%d unique)", nrow(unique(j[c("title", "eissn", "pissn")])))),
    journals_table(j)
  )
}
