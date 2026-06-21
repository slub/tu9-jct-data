# TU9 Transformative Agreements

Weekly snapshot of [Journal Checker Tool](https://journalcheckertool.org/transformative-agreements/)
(JCT) transformative-agreement data for the [TU9](https://www.tu9.de/) universities,
the alliance of nine German universities of technology. Agreement names, publishers
and consortia are enriched from the
[ESAC registry](https://esac-initiative.org/about/transformative-agreements/agreement-registry/).
Published as CSV files and a website.

📊 **Website:** https://slub.github.io/tu9-jct-data/  
📁 **Data:** the [`data/`](data/) directory

## What you get

Two views — agreements and the journals they cover — for all TU9 universities and
per institution:

| View | Files |
| --- | --- |
| **All agreements** with at least one TU9 participant | [`data/agreements.csv`](data/agreements.csv) |
| **All journals** covered by those agreements | [`data/journals.csv`](data/journals.csv) |
| **Per institution** — the same two views | `data/<institution>/agreements.csv` and `journals.csv` |

Plus [`data/esac.csv`](data/esac.csv) — ESAC registry metadata (id, name, publisher,
consortium, dates) used to enrich the agreements. Pipeline inputs live in `data-raw/`:
[`orgs.csv`](data-raw/orgs.csv) (TU9 institutions and their ROR ids) and
[`urls.csv`](data-raw/urls.csv) (each institution's open-access page).

### Columns

#### `agreements.csv`

| Column | Meaning |
| --- | --- |
| `esac_id` | ESAC registry identifier of the agreement |
| `relationship` | Sub-package / relationship within the agreement |
| `ca_only` | Corresponding-author-only: OA covered only when the TU9 author is the corresponding author |
| `end_date` | Agreement end date |
| `last_reviewed` | When the JCT entry was last reviewed |
| `data_url` | Source CSV for this agreement sub-package |
| `members_slug` | TU9 institutions participating (semicolon-separated slugs) |
| `members_ror` | Exact matched ROR ids for those TU9 participants |

#### `journals.csv`

| Column | Meaning |
| --- | --- |
| `title` | Journal name |
| `eissn` | ISSN (online) |
| `pissn` | ISSN (print) |
| `esac_id` | Agreement the journal is covered by |
| `data_url` | Source CSV for that agreement sub-package |
| `members_slug` | TU9 institutions participating (semicolon-separated slugs) |
| `members_ror` | Exact matched ROR ids for those TU9 participants |

#### `esac.csv`

| Column | Meaning |
| --- | --- |
| `id` | ESAC ID (joins to `esac_id` above) |
| `name` | Agreement name |
| `publisher` | Publisher |
| `consortium` | Negotiating consortium or institution |
| `start_date` | Agreement start date |
| `end_date` | Agreement end date (per the ESAC registry) |

## Matching

An agreement is listed for a university when one of that university's
[ROR](https://ror.org/) ids appears among the agreement's participating institutions.
The [Background](https://slub.github.io/tu9-jct-data/background.html) page documents
the method in full.

To extend coverage, add the ROR id as a new row in
[`data-raw/orgs.csv`](data-raw/orgs.csv) under the institution's `slug` (the first row
for a slug sets its display name). For a brand-new institution, also add a `slug,url`
row to [`data-raw/urls.csv`](data-raw/urls.csv). No code changes needed.

## How it works

```
data-raw/orgs.csv ─► scripts/fetch.R ─► scripts/esac.R ─► data/*.csv ─► Quarto site ─► GitHub Pages
  (TU9 ROR ids)       (weekly cron)      (ESAC enrich)     (committed)
```

`fetch.R` keeps every JCT agreement with a TU9 participant and writes the CSV views,
aborting if the count drops by more than 20 % versus the committed data. `esac.R` adds
publisher metadata, best effort — a stale registry link is non-fatal. `gen_pages.R`
builds the per-institution pages. The weekly
[`refresh.yml`](.github/workflows/refresh.yml) workflow fetches, commits and deploys;
[`pages.yml`](.github/workflows/pages.yml) rebuilds the site from committed data without
fetching. Deployment is via GitHub Actions (set **Settings → Pages → Source** to GitHub
Actions once).

## Running it yourself

Requires R (≥ 4.2) and [Quarto](https://quarto.org/); R dependencies are pinned with
[`renv`](https://rstudio.github.io/renv/).

```sh
Rscript -e 'renv::restore()'   # install pinned R packages
Rscript scripts/fetch.R        # refresh the data
Rscript scripts/gen_pages.R    # build per-institution pages
quarto render                  # build the site into _site/
```

While editing, render a single page with `quarto preview <page.qmd>` or
`scripts/render.sh <page.qmd>` instead of the full, slow site build.

## Licensing

- **Code** (R scripts, Quarto config, workflows): [MIT](LICENSE)
- **Data** ([`data/`](data/)): [CC0 1.0](data/LICENSE), matching the upstream JCT data.
