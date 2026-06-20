#!/usr/bin/env Rscript
# Quarto post-render step: copy the data files into the rendered site at clean,
# prefix-free URLs (no /data/ or /data-raw/). Runs after `quarto render`, which
# sets QUARTO_PROJECT_OUTPUT_DIR to the output directory (_site).
#
#   data/agreements.csv         -> /agreements.csv
#   data/journals.csv           -> /journals.csv
#   data/esac.csv               -> /esac.csv
#   data/meta.json              -> /meta.json
#   data/LICENSE                -> /DATA-LICENSE   (CC0; renamed so a root
#                                                   /LICENSE is not mistaken for
#                                                   the whole site's licence)
#   data-raw/orgs.csv           -> /orgs.csv
#   data-raw/urls.csv           -> /urls.csv
#   data/<slug>/agreements.csv  -> /institutions/<slug>/agreements.csv
#   data/<slug>/journals.csv    -> /institutions/<slug>/journals.csv

out <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", "_site")

publish <- function(from, to) {
  dest <- file.path(out, to)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  if (!file.copy(from, dest, overwrite = TRUE))
    stop("publish_data.R: failed to copy ", from, " -> ", dest)
}

# Top-level data products, metadata and the data licence.
publish("data/agreements.csv", "agreements.csv")
publish("data/journals.csv",   "journals.csv")
publish("data/esac.csv",       "esac.csv")
publish("data/meta.json",      "meta.json")
publish("data/LICENSE",        "DATA-LICENSE")

# Build inputs.
publish("data-raw/orgs.csv", "orgs.csv")
publish("data-raw/urls.csv", "urls.csv")

# Per-institution views, under /institutions/<slug>/ to mirror the page paths.
slugs <- list.dirs("data", recursive = FALSE, full.names = FALSE)
slugs <- slugs[nzchar(slugs)]
for (slug in slugs) {
  for (f in c("agreements.csv", "journals.csv")) {
    src <- file.path("data", slug, f)
    if (file.exists(src)) publish(src, file.path("institutions", slug, f))
  }
}

message("publish_data.R: published data files into ", out, "/")
