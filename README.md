# TU9 Transformative Agreements

Regularly updated metadata about **transformative agreements** for the
[TU9](https://www.tu9.de/) universities – the alliance of nine leading German
institutes of technology.

The data is fetched from the
[Journal Checker Tool](https://journalcheckertool.org/transformative-agreements/)
("Transformative Agreements Public Data"), refreshed automatically every week,
and published both as plain CSV files and as a browsable website.

📊 **Website:** https://slub.github.io/tu9-jct-data/
📁 **Data:** the [`data/`](data/) directory of this repository

## What you get

Three views of the same data:

| View | Files |
| --- | --- |
| **All agreements** with at least one TU9 participant | [`data/agreements.csv`](data/agreements.csv) |
| **All journals** covered by those agreements | [`data/journals.csv`](data/journals.csv) |
| **Per institution** — one folder each | `data/<institution>/agreements.csv` and `journals.csv` |

The TU9 institutions and their identifiers are listed in
[`data-raw/orgs.csv`](data-raw/orgs.csv).

### Columns

`agreements.csv`

| Column | Meaning |
| --- | --- |
| `esac_id` | ESAC registry identifier of the agreement |
| `relationship` | Sub-package / relationship within the agreement |
| `end_date` | Agreement end date |
| `last_reviewed` | When the JCT entry was last reviewed |
| `data_url` | Source CSV for this agreement sub-package |
| `members` | TU9 institutions participating (semicolon-separated slugs) |

`journals.csv`

| Column | Meaning |
| --- | --- |
| `title` | Journal name |
| `eissn` | ISSN (online) |
| `pissn` | ISSN (print) |
| `esac_id` | Agreement the journal is covered by |
| `url` | Source CSV for that agreement sub-package |
| `members` | TU9 institutions participating |

## How an institution is matched

An agreement is listed for a university when **any of that university's
[ROR](https://ror.org/) identifiers** appears among the agreement's
participating institutions. Matching is deliberately **strict — precision
first**: an institution is represented only by ROR ids it explicitly claims.

An institution can have more than one ROR — for example, Technische Universität
Dresden also counts agreements registered under its library, the
[SLUB Dresden](https://ror.org/03wf51b65). To extend coverage, add the extra
ROR identifier as a **new row in [`data-raw/orgs.csv`](data-raw/orgs.csv) with
the same `slug`** as the institution it belongs to; the first row for a slug
provides the display name. No code changes are needed.

## How it works

```
data-raw/orgs.csv   ──►  scripts/fetch.R  ──►  data/*.csv  ──►  Quarto site ──► GitHub Pages
   (TU9 ROR ids)          (weekly cron)        (committed)      (per-institution pages)
```

1. `scripts/fetch.R` reads the JCT index, downloads each agreement, keeps those
   with a TU9 participant, and writes all CSV views plus `data/meta.json`.
2. A **guard rail** aborts the run without overwriting if the number of
   agreements drops by more than 20 % compared to the committed data (protects
   against a bad fetch). Re-run from the Actions tab with *force* to override.
3. `scripts/gen_pages.R` creates one Quarto page per institution.
4. The site is rendered and deployed to GitHub Pages.

Two GitHub Actions workflows drive this:

- [`refresh.yml`](.github/workflows/refresh.yml) — the **weekly cron**: fetches
  fresh data, commits it, then rebuilds and deploys the site.
- [`pages.yml`](.github/workflows/pages.yml) — a **lightweight rebuild** that
  re-renders and deploys the site from the data already in the repo, *without*
  fetching. It runs automatically when site code is pushed to `main`, or on
  demand from the Actions tab — handy after a layout or wording change.

## Running it yourself

Requirements: R (≥ 4.2) and [Quarto](https://quarto.org/). Dependencies are
pinned with [`renv`](https://rstudio.github.io/renv/).

```sh
Rscript -e 'renv::restore()'   # install pinned R packages
Rscript scripts/fetch.R        # refresh the data
Rscript scripts/gen_pages.R    # build per-institution pages
quarto render                  # build the website into _site/
```

## First-time setup (maintainers)

The website is deployed straight from the workflow. In the repository settings
under **Settings → Pages**, set the source to **GitHub Actions**. After that,
every scheduled run rebuilds and republishes the site automatically.

## Licensing

- **Code** (R scripts, Quarto config, workflows): [MIT](LICENSE)
- **Data** (everything in [`data/`](data/)): [CC0 1.0](data/LICENSE), matching
  the upstream Journal Checker Tool data.

## Acknowledgements

Data source: [Journal Checker Tool](https://journalcheckertool.org/) by cOAlition S.
Inspired by [`njahn82/jct_data`](https://github.com/njahn82/jct_data) and the
SLUB Dresden reporting workflows.
