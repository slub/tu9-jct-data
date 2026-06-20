#!/usr/bin/env Rscript
# Generate one Quarto page per institution (institutions/<slug>.qmd) from the
# template below. Run this after fetch.R and before `quarto render`.

source("scripts/jct.R")
orgs <- read_orgs()
orgs <- orgs[!duplicated(orgs$slug), ]   # one page per institution

# Each institution's own page on open-access agreements and funding support,
# matched onto orgs by slug. Slugs without a row get NA (no intro link).
urls <- read_csv("data-raw/urls.csv", col_types = cols(.default = col_character()))
orgs$url <- urls$url[match(orgs$slug, urls$slug)]

dir.create("institutions", showWarnings = FALSE)

template <- '---
title: "%s"
---

```{r}
source("scripts/site_helpers.R")
inst_page("%s", url = %s)
```
'

# Render the url argument as a quoted string, or NULL when absent.
url_arg <- function(u) if (is.na(u)) "NULL" else sprintf('"%s"', u)

for (i in seq_len(nrow(orgs))) {
  writeLines(
    sprintf(template, orgs$name[i], orgs$slug[i], url_arg(orgs$url[i])),
    file.path("institutions", paste0(orgs$slug[i], ".qmd"))
  )
}
message("Generated ", nrow(orgs), " institution pages.")
