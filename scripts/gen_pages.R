#!/usr/bin/env Rscript
# Generate one Quarto page per institution (institutions/<slug>.qmd) from the
# template below. Run this after fetch.R and before `quarto render`.

source("scripts/jct.R")
orgs <- read_orgs()
orgs <- orgs[!duplicated(orgs$slug), ]   # one page per institution
dir.create("institutions", showWarnings = FALSE)

template <- '---
title: "%s"
---

```{r}
source("scripts/site_helpers.R")
inst_page("%s")
```
'

for (i in seq_len(nrow(orgs))) {
  writeLines(
    sprintf(template, orgs$name[i], orgs$slug[i]),
    file.path("institutions", paste0(orgs$slug[i], ".qmd"))
  )
}
message("Generated ", nrow(orgs), " institution pages.")
