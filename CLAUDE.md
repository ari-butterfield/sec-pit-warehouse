# sec-pit-warehouse

A point-in-time warehouse over the SEC Financial Statement Data Sets.

**Thesis:** companies restate their financials. A naive warehouse overwrites the
old number and loses the fact that, on a given date, the market believed
something different. This warehouse keeps every filed version of every fact, so
you can ask "what was knowable on date D" and downstream models cannot leak
future restatements backwards (lookahead bias). Bi-temporal: *valid time* is the
period a fact describes, *transaction time* is when it was filed.

**Stack:** dlt (ingest) → GCS Parquet → BigQuery `sec_raw` → dbt (staging →
intermediate → marts). DuckDB is dev and CI, BigQuery is prod. Terraform for
infra. GitHub Actions CI has been merge-blocking since day 1.

---

## How to work with me

I'm an analytics engineer with 2 years of experience, building this as a
portfolio project to land an analytics/data engineering role. I know SQL well.
I am new to dlt, dbt, BigQuery, Terraform, and dimensional modeling.

I have to be able to explain every line of this repo in an interview. That
constraint outranks speed.

- **Explain before you code.** When I ask how to build something, describe the
  approach first and stop. Let me write it. Then review what I wrote and tell
  me plainly what is wrong.
- **Do not author these for me:** the intermediate models, the singular tests,
  the README's decisions section, `docs/data_model.md`. Review them and argue
  with them, but do not write them.
- **You can author:** YAML scaffolds, staging renames, Terraform copied from
  provider docs, test boilerplate, shell commands.
- **Be direct.** If my SQL is wrong, my grain is confused, or my plan will not
  work, say so in the first sentence.
- Anything I keep but cannot explain out loud gets deleted.

## Before proposing anything

Read `docs/architecture.md`. It has a dated decision log and an XBRL trap list.
Decisions recorded there are settled; do not re-litigate them without a reason.
`docs/backlog.md` has what is deliberately out of scope.

## Vocabulary

**Use:** point-in-time, bi-temporal, lookahead bias, authoritative, restatement,
revision, lineage, provenance, as-of, reconcile.

**Never use, in code, commits, docs, or comments:** trading, alpha, backtest,
signal, returns, strategy, predict. This repo is about data reliability, not
about finance.

## Style

- Comment *why*, never *what*, and not on every third line.
- Plain names: `download_quarter`, not `SECDataIngestionOrchestrator`.
- No defensive `try/except` around code that cannot fail. Let it raise.
- Conventional commits (`feat:`, `fix:`, `test:`, `docs:`) that state the
  *reason*, not the diff. Good: `feat: read sec files as raw strings so schema
  doesn't drift across quarters`. Bad: `feat: implement robust ingestion layer`.
- Small, frequent commits. Branch → PR → green CI → squash merge.
- No em dashes in prose.

---

## Layout

```
infra/            Terraform: GCS bucket, BigQuery datasets, service account
ingest/
  sources/        dlt source over the SEC quarterly ZIPs
  tests/          pytest + a committed 200-row fixture quarter
transform/        dbt project (models/{staging,intermediate,marts}, tests/)
docs/
  architecture.md decision log + XBRL trap list  ← read this first
  data_model.md   grain and resolution rules
  backlog.md      known-deferred work
.github/workflows/ci.yml   ruff, sqlfluff, pytest, dbt build. Merge-blocking.
```

## Commands

```bash
source .venv/bin/activate          # Python 3.12 via uv; use `uv pip`, not pip
pytest -q                          # from repo root
cd transform && dbt build          # DuckDB (dev)
cd transform && dbt build --target prod   # BigQuery
cd ingest && python load_sec_quarter.py 2026q1 --destination bigquery
pre-commit run --all-files         # before every commit
```

## Environment notes

- WSL on Windows. Python 3.12 in `.venv` via `uv`. The venv has no `pip`, use
  `uv pip install`.
- dlt resolves `.dlt/config.toml` relative to the working directory, so dlt
  commands run from `ingest/`.
- `GOOGLE_APPLICATION_CREDENTIALS` is set in my shell. Terraform must not use
  it, because that service account has no IAM rights. Run
  `env -u GOOGLE_APPLICATION_CREDENTIALS terraform ...`.
- pytest runs from the repo root; `pythonpath = ["ingest"]` is in
  `pyproject.toml`.
- Never commit: `infra/.secrets/`, `*.tfstate*`, `.terraform/`,
  `ingest/.cache/`, `*.duckdb`, `backfill.log`.

## State

Done: repo scaffold, blocking CI, dlt source, 29-quarter backfill in BigQuery
(partitioned by `source_quarter_start`, `num` clustered by `adsh, tag`),
Terraform applied, staging through marts building on both DuckDB and BigQuery,
three singular tests including `assert_no_lookahead`, all published figures
measured on the full backfill.

Open: the write-ups in `docs/data_model.md` and the README's decisions section.
