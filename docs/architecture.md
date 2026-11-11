# Architecture

## Decision log

### 2026-08-20 - Jinja templater used for SQLFluff

I chose the jinja templater over the dbt templater for SQLFluff because it runs faster and it doesn't matter if I get the real table names for linting purposes. I lose the check that the ref() tables actually exist but this will be checked already in the dbt build step.

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

### 2026-08-24 - GCS Parquet staging, not streaming inserts

dlt writes Parquet to GCS and BigQuery loads from there. Load jobs are free, while streaming is billed per byte. I don't need the streaming feature. The GCS files also let me reload BigQuery without re-downloading from the SEC.

### 2026-08-24 - Separate pipeline name for BigQuery

BigQuery uses `sec_fsds_bq`, local stays `sec_fsds`. dlt's local state is keyed to the pipeline name only, so sharing a name across two destinations means clearing state every time I switch. DuckDB is dev and CI, BigQuery is prod.

### 2026-08-27 - Added unit of measure to the grain

Unit of measure was just reporting various currencies, such as USD, CAD, etc... Two values in different currencies represents two facts. They are not a disagreement about a fact, so there is no reason to filter.

## Data trap list

### num.txt has ten columns; SEC published spec mentions nine.

The 'segments' column isn't mentioned in the SEC public spec. This holds a dimensional qualifier; one slice of the company total. I've decided to filter the num table to segments='' in order to keep a consistent grain. This avoids conflicts from different segments that match date, company, and type of value. Adding segments will be a v2 feature.

### 'qtrs' semantics

'qtrs' values: 0 = instantaneous, 1 = one quarter, 2 = six months, 4 = annual.

Measured on the 29-quarter backfill, that list is incomplete. qtrs = 3 (nine months) is
2,987,075 authoritative facts, 12.3% of the table, so it is not a tail case. There is
also a long tail of larger values up to 128, which are cumulative inception-to-date
periods or filer errors.

### Q4 is never filed

Q4 is never filed, but must be derived as FY minus Q1+Q2+Q3. This is dangerous if the quarterly numbers come from different filed dates, as restatements could result in incorrect Q4 calculations.

### Tag names are not stable or guessable

Apple files revenue as RevenueFromContractWithCustomerExcludingAssessedTax, not Revenues. Some tags are custom. Tags may have multiple versions. Therefore, (tag, version) is the primary key and not tag alone.

### 'ddate' is rounded to the nearest month end and carries implausible values

'ddate' cannot be treated as an exact reported date.

It also carries implausible values. Across 29 quarters end_date runs from 1011-12-31 to
2923-12-31: 36 rows before 1990 and 59 after 2030, out of 45,945,981. The low end is
filer typos. The high end is mixed, because lease and debt maturity schedules legitimately
report period ends years ahead, which is why date_filed < end_date was rejected as a
lookahead signal. Both tails are small enough that a bounds test is cheap. No test bounds
either end yet; the backlog entry is 'ddate sanity test'.

### A filing reports many periods

Each 10-K and 10-Q reports prior-period values to compare. Filed date is often years after ddate. This is why the fact grain is bi-temporal: when the fact was true, and the date it was filed.

### Backfilling quarters had huge unsplit chunks

29-quarter backfill was split into 1GB, 1GB, 97MB chunks, and only the 97MB chunk would complete, and it would take many hours without completing a 1GB chunk. This also costs any mid-chunk process upon restart. config now sets file_max_bytes to 33MB.

### 'sub.filed' is format YYYYMMDD. A plan try_cast() silently nulls it

Filing dates return NULL with try_cast(). This field requires try_strptime() with the proper format.

### date_filed < end_date is not a reliable lookahead signal
Ordinary tags (CommonStockSharesIssued, OperatingLeaseLiabilityNoncurrent, etc.)
routinely have end_date at or after date_filed, with no clean tag/qtrs-based way
to separate legitimate cases from real errors. That bound shipped instead as
assert_no_future_filings, which checks only date_filed > current_date.

assert_no_lookahead was left holding the resolution rule: no version of a fact may be
filed later than the row chosen as authoritative for it. It is a regression guard on
int_facts__authoritative rather than an independent check.

## Daily log

### 2026-08-20 - Scaffolding
Today I setup the scaffolding for my dbt warehouse. I added docs for the architecture, backlog, data models. I added an outline for the README. I setup the CI pipeline with linting and tests so that I can always enforce a working model (and enforce bi-temporality in the future) and block incorrect merges. I got dbt connected and working with DuckDB.

### 2026-08-23 - Load SEC data
Today I wrote the dlt source and loader for the SEC quarterly datasets: download, parse the files, and load them into duckdb. Already loaded quarters are skipped using the dlt state. I explored the data and started a trap list.

### 2026-08-24 - BigQuery and tests
Used Terraform for the bucket, datasets, and service account. Pointed dlt at GCS to BigQuery with partitioning and clustering. Fixed a concurrency bug in the download cache. Landed the deferred tests, so pytest runs in CI and the no-op re-run is proven by a test. Launched the 29-quarter backfill overnight.

### 2026-08-25 - Staging views and intermediate verioned facts table
Built staging views for naming and casting the columns from the sub, num, and tag sources. Built the versioned intermediate facts table off of the sub and num staging views. Fixed and finished the 29-quarter backfill.

### 2026-08-27 - Authoritative facts intermediate table
Deduped the results in the intermediate versioned facts table. Realized that the unit of measure needs to be added to the grain for various currencies of the same fact, but nothing else.

Built the authoritative facts table. This resolves all values that were revised or re-reported by choosing the latest filing date. The acceptance date and accession number are used as tiebreakers. I used a windows function. Also, the filing date column was returning NULL. I debugged and realized that try_cast() was silently returning NULL because of the date format of the column, so I switched to strptime().

### 2026-09-18 - Marts restatement event table
Created an event table catching all distinct facts that have revised numerical values.
Ran in BigQuery and resolved all the syntax conflicts between DuckDB and BigQuery SQL using macros.
I ran SQL queries to find the revision rate of facts and also how many companies revise
at least one fact and I reported these as headline numbers in the README.

### 2026-09-20 - No lookahead and one authoritative value tests
Created a test to confirm that the authoritatiave facts table only stores a single value per fact.
Created an additional test that all filing dates are before the current date. Initially I wanted
to confirm that no facts are filed regarding a period that ends after the filing date. In reality,
many ordinary tags e.g. CommonStockSharesIssues routinely report the number for that period before
the period ends because the information is already available.

### 2026-09-22 - Measured data figures on the 29-quarter backfill and filled documentation

The headline numbers demonstrate a substantial amount of revisions. 89.7% of companies
revised at least one fact. The per-fact revision rate is 3.57%. Only 4.40% of reassertion
events are actual value revisions. The mart classifies reasserted and revised values separately.

Revision lag demonstrated how reassertions cluster at the annual comparative refilings.
There is a median lag of 361 days, with a p90 of 371 days, which clusters around annual
refilings rather than randomly distributed reassertions.

Filled out the README and docs/data_model.md with measured figures on the data,
and closed out the cost section: 34.1 GiB in BigQuery plus 2.59 GiB in GCS, roughly
$0.48/month, with a full rebuild scanning 27.4 GiB. Confirmed that the counts reconcile
across models.

### 2026-11-10 - Cleaned documentation
Rewrote the README and the backlog, and cleared the architecture file of irrelevant decisions.
Edited the company dimension's fields as it made sense and added some comments to ingest.
