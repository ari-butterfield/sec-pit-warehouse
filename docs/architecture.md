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

### 2026-08-24 - Add real DATE column at ingest for partitioning

Add column 'source_quarter_start', and fill it with the first day of the quarter. The original plan was to partition on the 'source_quarter' string, but BigQuery only accepts DATE, TIMESTAMP, DATETIME, INTEGER as partition keys. Partition on this column in order to prune irrelevant quarters when querying a particular quarter.

Cluster num on (adsh, tag). num has no cik, so it is not possible to cluster by company. sub is clustered on cik. adsh groups rows by filing. tag is a good second, because (adsh, tag) will filter well if certain fields for a particular filing are queried.

Hints are creation-only. Altering partitioning requires recreating the tables, so these hints are incorporated before the 29-quarter backfill of the BigQuery tables.

After loading two quarters: a full scan costs 98 MB vs. a single partition (1 quarter) costs 78 MB. Smaller reduction than 50% partition suggests, but query reads partition column and partitions differ in size. I will recheck when there are more partitions and the ration is larger.

### 2026-08-24 - Service-account key instead of WIF key

WIF issues tokens from an external identity so there's no key to leak. Rejected because service-account key takes 15 mins to set up and it never leaves my machine or repo.

### 2026-08-24 - Project-scoped IAM

bigquery.dataEditor and bigquery.jobUser are granted at the project level, so the pipeline SA can write to any dataset in the project. Dataset-scoped (google_bigquery_dataset_iam_member) is least-privilege and correct for dataEditor; chose project-scoped for speed. jobUser has to stay project-level either way as jobs are a project-level operation.

### 2026-08-24 - GCS Parquet staging, not streaming inserts

dlt writes Parquet to GCS and BigQuery loads from there. Load jobs are free; streaming is billed per byte for freshness I don't need from quarterly data. The GCS files also let me reload BigQuery without re-downloading from the SEC.

### 2026-08-24 - Separate pipeline name for BigQuery

BigQuery uses `sec_fsds_bq`, local stays `sec_fsds`. dlt's local state is keyed to the pipeline name only, so sharing a name across two destinations means clearing state every time I switch. DuckDB is dev and CI, BigQuery is prod.

### 2026-08-24 - Per-thread staging filename in the download cache

The four resources extract concurrently and all download the same quarter. They shared one ".part" file, so one renamed it and the next crashed. Fixed by making the temp name unique per thread.

### 2026-08-24 - Added legacyBucketReader to the service account

storage.objectAdmin doesn't include storage.buckets.get. gcsfs checks the bucket first, got a 403, and reported it as "Bucket does not exist" - so I chased a bucket that existed.

## Data trap list

### num.txt has ten columns; SEC published spec mentions nine.

The 'segments' column isn't mentioned in the SEC public spec. This holds a dimensional qualifier; one slice of the company total. I've decided to filter the num table to segments='' in order to keep a consistent grain. This avoids conflicts from different segments that match date, company, and type of value. Adding segments will be a v2 feature.

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

### Backfilling quarters had huge unsplit chunks

29-quarter backfill was split into 1GB, 1GB, 97MB chunks, and only the 97MB chunk would complete, and it would take many hours without completing a 1GB chunk. This also costs any mid-chunk process upon restart. config now sets file_max_bytes to 33MB.

## Daily log

### 2026-08-20 - Scaffolding
Today I setup the scaffolding for my dbt warehouse. I added docs for the architecture, backlog, data models. I added an outline for the README. I setup the CI pipeline with linting and tests so that I can always enforce a working model (and enforce bi-temporality in the future) and block incorrect merges. I got dbt connected and working with DuckDB.

### 2026-08-23 - Load SEC data
Today I wrote the dlt source and loader for the SEC quarterly datasets: download, parse the files, and load them into duckdb. Already loaded quarters are skipped using the dlt state. I explored the data and started a trap list.

### 2026-08-24 - BigQuery and tests
Used Terraform for the bucket, datasets, and service account. Pointed dlt at GCS to BigQuery with partitioning and clustering. Fixed a concurrency bug in the download cache. Landed the deferred tests, so pytest runs in CI and the no-op re-run is proven by a test. Launched the 29-quarter backfill overnight.

### 2026-08-25 - Staging views and intermediate table
Built staging views for naming and casting the columns from the sub, num, and tag sources. Built an intermediate facts table off of the sub and num staging views. Fixed and finished the 29-quarter backfill.
