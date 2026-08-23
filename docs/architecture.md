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

### 2026-08-23 - Raw layer is all strings

Typing happens in staging to avoid casting to the wrong type.

### 2026-08-23 - Raw is append-only with quarter-level state, not merge

This avoids double loading quarter-level data into the database before removing redundant data

## Data trap list

### num.txt has ten columns; SEC published spec mentions nine.

The 'segments' column isn't mentioned in the SEC public spec. This holds a dimensional qualifier; one slice of the company total. 'segments' will need to be added to the grain.

### 'qtrs' semantics

'qtrs' values: 0 = instantaneous, 1 = one quarter, 4 = annual, 2 = six months

### Q4 is never filed

Q4 is never filed, but must be derived as FY minus Q1+Q2+Q3. This is dangerous if the quarterly numbers come from different filed dates, as restatements could result in incorrect Q4 calculations.

### The same facts appear in multiple filings with different values

Holding (cik, tag, version, ddate, qtrs, uom, coreg, segments) fixed, the same fact still
appears under multiple adsh values with different filed dates. When matching entries disagree, this indicates a revision of values on a different filing date.

### Tag names are not stable or guessable

Apple files revenue as RevenueFromContractWithCustomerExcludingAssessedTax, not Revenues. Some tags are custom. Tags may have multiple versions. Therefore, (tag, version) is the primary key and not tag alone.

### 'ddate' is rounded to the nearest month end

'ddate' cannot be treated as an exact reported date.

### A filing reports many periods

Each 10-K and 10-Q reports prior-period values to compare. Filed date is often years after ddate. This is why the fact grain is bi-temporal: when the fact was true, and the date it was filed.

## Daily log

### 2026-08-20 - Scaffolding
Today I setup the scaffolding for my dbt warehouse. I added docs for the architecture, backlog, data models. I added an outline for the README. I setup the CI pipeline with linting and tests so that I can always enforce a working model (and enforce bi-temporality in the future) and block incorrect merges. I got dbt connected and working with DuckDB.

### 2026-08-23 - Load SEC data
Today I wrote the dlt source and loader for the SEC quarterly datasets: download, parse the files, and load them into duckdb. Already loaded quarters are skipped using the dlt state. I explored the data and started a trap list.
