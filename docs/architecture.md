# Architecture

## Decision log

### 2026-08-20 - Jinja templater used for SQLFluff

I chose the jinja templater over the dbt templater for SQLFluff because it runs faster and it doesn't matter if I get the real table names for linting purposes. I lose the check that the ref() tables actually exist but this will be checked already in the dbt build step.

### 2026-08-20 - Profiles.yml committed inside transform/

I kept the profiles.yml in the repo because it connects to my DuckDB file. The file and the filepath are not private. CI and a cold clone can both run dbt build with no setup.

### 2026-08-23 — Evaluated secfsdstools, not using it

`secfsdstools` reads and parses these datasets fine, but it also builds its own Parquet store and a SQLite index you query through its collector classes. Its a complete data warehouse, which is the point of this project. I'll take dependencies for solved problems, but not the core of this project.

It would save my about forty lines of `requests` and `zipfile`. Those forty lines are where the encoding and quoting traps live, so I'd rather own them.

### 2026-08-23 - Kept 'quoting = QUOTE_NONE' in 'read_csv()'

Treats all quotes as ordinary characters. In my test on 2026q1, this costs 2 unparseable rows out of ~5.2M, from tabs enclosed in quotes. I believe this is an acceptable trade-off, because this prevents silently swallowing tabs and shifting columns without error.

## Data trap list

### num.txt has ten columns; SEC published spec mentions nine.

The 'segments' column isn't mentioned in the SEC public spec. This holds a dimensional qualifier; one slice of the company total. Will need to be resolved.

## Daily log

### 2026-08-20 - Scaffolding
Today I setup the scaffolding for my dbt warehouse. I added docs for the architecture, backlog, data models. I added an outline for the README. I setup the CI pipeline with linting and tests so that I can always enforce a working model (and enforce bi-temporality in the future) and block incorrect merges. I got dbt connected and working with DuckDB.
