# Architecture

## Decision log

### 2026-08-20 - Jinja templater used for SQLFluff

I chose the jinja templater over the dbt templater for SQLFluff because it runs faster and it doesn't matter if I get the real table names for linting purposes. I lose the check that the ref() tables actually exist but this will be checked already in the dbt build step.

### 2026-08-20 - Profiles.yml committed inside transform/

I kept the profiles.yml in the repo because it connects to my DuckDB file. The file and the filepath are not private. CI and a cold clone can both run dbt build with no setup.
