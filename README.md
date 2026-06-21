# TU9 Transformative Agreements

Regularly updated metadata about transformative agreements for the
[TU9](https://www.tu9.de/) universities — the alliance of nine leading German
institutes of technology.

The data is fetched from the
[Journal Checker Tool](https://journalcheckertool.org/transformative-agreements/)
("Transformative Agreements Public Data"), refreshed automatically every week,
and published both as plain CSV files and as a browsable website. Agreement
names, publishers and consortia are enriched from the
[ESAC Transformative Agreement Registry](https://esac-initiative.org/about/transformative-agreements/agreement-registry/).

📊 **Website:** https://slub.github.io/tu9-jct-data/  
📁 **Data:** the [`data/`](data/) directory of this repository

## What you get

Two views — agreements and the journals they cover — for all TU9 universities
and per institution:

| View | Files |
| --- | --- |
| **All agreements** with at least one TU9 participant | [`data/agreements.csv`](data/agreements.csv) |
| **All journals** covered by those agreements | [`data/journals.csv`](data/journals.csv) |
| **Per institution** — the same two views, one folder each | `data/<institution>/agreements.csv` and `journals.csv` |

Plus [`data/esac.csv`](data/esac.csv) — ESAC registry metadata (id, name,
publisher, consortium, dates) used to enrich the agreements.

The pipeline inputs live in `data-raw/`:
[`orgs.csv`](data-raw/orgs.csv) (TU9 institutions and their ROR identifiers) and
[`urls.csv`](data-raw/urls.csv) (each library's open-access funding page).

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
| `name` | Agreement name / labeling |
| `publisher` | Publisher |
| `consortium` | Negotiating consortium or institution |
| `start_date` | Agreement start date |
| `end_date` | Agreement end date (per the ESAC registry) |

## How an institution is matched

An agreement is listed for a university when one of that university's
[ROR](https://ror.org/) identifiers appears among the agreement's
participating institutions. A university is represented by its own ROR ids.

An institution can have more than one ROR — most notably when its library is a
standalone organisation with its own ROR. Two TU9 libraries are like this and
are counted under their university:

- Technische Universität Dresden + [SLUB Dresden](https://ror.org/03wf51b65)
- Leibniz Universität Hannover + [TIB](https://ror.org/04aj4c181)

University clinics are not counted: in this data they only appear
on agreements where the university itself is already a participant, so they add
no coverage.

To extend coverage, add the extra ROR identifier as a new row in
[`data-raw/orgs.csv`](data-raw/orgs.csv) with the same `slug` as the
institution it belongs to; the first row for a slug provides the display name.
No code changes are needed.

When adding a brand-new institution (a new `slug`), also add a matching row
to [`data-raw/urls.csv`](data-raw/urls.csv) (`slug,url`) pointing to the
institution's own page on open-access agreements and funding support. A slug
without a row simply renders without that link.

## How it works

```
data-raw/orgs.csv   ──►  scripts/fetch.R  ──►  scripts/esac.R  ──►  data/*.csv  ──►  Quarto site ──► GitHub Pages
   (TU9 ROR ids)          (weekly cron)        (ESAC enrichment)     (committed)      (per-institution pages)
```

1. `scripts/fetch.R` reads the JCT index, downloads each agreement, keeps those
   with a TU9 participant, and writes all CSV views plus `data/meta.json`.
2. A guard rail aborts the run without overwriting if the number of
   agreements drops by more than 20 % compared to the committed data (protects
   against a bad fetch). Re-run from the Actions tab with *force* to override.
3. `scripts/esac.R` enriches those agreements with name, publisher and
   consortium from the ESAC TA Registry, writing `data/esac.csv`. It is best
   effort: the registry is a snapshot behind a rotating share link, so any
   download error is non-fatal — the last-good `data/esac.csv` is kept and the
   refresh continues. Bump the URL in `scripts/esac.R` when ESAC publishes a new
   registry.
4. `scripts/gen_pages.R` creates one Quarto page per institution, linking each
   to the institution's own page on open-access agreements and funding support
   from [`data-raw/urls.csv`](data-raw/urls.csv) (matched by `slug`).
5. The site is rendered and deployed to GitHub Pages.

Two GitHub Actions workflows drive this:

- [`refresh.yml`](.github/workflows/refresh.yml) — the weekly cron: fetches
  fresh data, commits it, then rebuilds and deploys the site.
- [`pages.yml`](.github/workflows/pages.yml) — a lightweight rebuild that
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

While editing pages, `scripts/render.sh` rebuilds only the pages you name
(`scripts/render.sh background.qmd`), or — with no arguments — the `.qmd` files
you've changed, instead of re-rendering the whole site. For a live-reloading
preview, use `quarto preview <page.qmd>`.

This matters because a full `quarto render` is slow: about 9 minutes, most of it
the large `journals` page (~1 minute on its own). A single prose page renders in
a few seconds and a page with a data table (e.g. `index`) in well under ten, so
prefer per-page rendering during development (timings as of June 2026).

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
