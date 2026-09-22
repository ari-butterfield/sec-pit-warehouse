# Data model

Every model states its grain. Where a grain leaves a column out, the reason is stated.

Figures below were measured on BigQuery over the full 29-quarter backfill
(2019q1–2026q1): 45,945,981 consolidated facts, 24,278,748 authoritative facts,
11,115 companies.

## Staging

Rename and cast only; no business logic.

| Model | Source | Grain |
|---|---|---|
| `stg_sec__submissions` | `sec_raw.sub` | one row per filing (`accession_number`) |
| `stg_sec__numeric_facts` | `sec_raw.num` | one row per reported numeric fact per filing |
| `stg_sec__tags` | `sec_raw.tag` | one row per `(tag, version)` |

`stg_sec__numeric_facts` filters to `segments = ''`. Segment detail is a different
grain, one slice of a company rather than the company, and carrying it would make a segment
breakdown look like a competing version of the consolidated fact.

`stg_sec__tags` has no downstream consumer. `(tag, version)` is carried down from `num`
directly and the label text is not needed by any model.

## int_facts__versioned

The grain of `int_facts__versioned` is one row per (cik, tag, period_end, qtrs, adsh, uom).
That means: one company's one financial concept, for one period, as asserted by one
specific filing. Unit of measure accounts for various currencies. Two filings reporting
the same concept for the same period are two rows (two versions of the same fact), not a conflict.

Verified: zero groups collide on that key, so no single filing ever reports the same
concept twice for the same period and unit.

## int_facts__authoritative

The grain of `int_facts__authoritative` is one row per (cik, tag, period_end, qtrs, uom).
This is the same as `int_facts__versioned` minus the filing distinction. When two rows
have the same grain from different filings, this represents a revision or re-report of
the same fact.

When two rows have matching grains, the later `date_filed` is chosen over the earlier,
because it is the more current assertion about the same fact. `date_accepted` from `sub`
is the tiebreaker, for the case that two values are filed on the same day. The
`accession_number` (unique per filing) is the final backstop so there is always an
ordering and the result is always deterministic.

### `co_registrant` is not in the grain

Measured: `co_registrant` is an empty string on all 45,945,981 consolidated rows
(zero non-empty values). The column carries no information in this data.

### `version` is not in the grain

`version` records which dictionary edition the filer cited, not what was asserted.
Keeping it out of the grain is what lets the same concept, re-tagged under a newer
taxonomy, land in one group and resolve as a re-assertion instead of splitting into
two unrelated facts. In 0.11% of multi-filing groups the winning row cites an older
edition than one it beat, which is harmless as I resolve on date_filed, not on version.

## dim_company

One row per `cik`. Type 1, current attributes only, read from the company's most recent
filing, resolved with the same rule as `int_facts__authoritative` so a company's
descriptive attributes and its facts never disagree about which filing is current.

11,119 companies, a superset of the 11,115 that appear in `mart_fct_financial`, so the
foreign key holds with zero orphans, and the `relationships` tests on both marts pass. The
4 extra are filers whose submissions carried no numeric fact surviving `segments = ''`.

`date_filed` and `accession_number` record which filing the attributes came from, which
makes the Type 1 cut point explicit rather than implied. They keep the source column
names: every column on this model is "as of" that one filing, so qualifying two of them
and not the rest would imply a distinction that does not exist.

Keeping SCD1 costs me tracking history of company renames and SIC reclassifcations.
These are overwritten, SCD2 is a version 2 feature.

## mart_fct_financial

Same grain as `int_facts__authoritative`: one row per (cik, tag, period_end, qtrs, uom).
The authoritative facts exposed as a fact table, with `central_index_key` as a foreign
key to `dim_company` enforced by a `relationships` test.

As of now this matches 'int_facts__authoritative' but it is a separate model because
intermediate models are implementation and marts are the contract.


## mart_restatement_event

One row per **re-assertion**: a later filing reported a
(cik, tag, period_end, qtrs, uom) that an earlier filing already reported. The grain is
that key plus `revising_adsh`.

This is *not* one row per restatement. Most re-assertions repeat the number unchanged,
so `revision_type` is what separates a real restatement from a reaffirmation:

| `revision_type` | Meaning | Events | Share |
|---|---|---|---|
| `reaffirmation` | re-reported, value identical | 20,149,068 | 92.99% |
| `value_revision` | **the number moved** | 954,391 | 4.40% |
| `both_absent` | neither filing carried a value | 513,777 | 2.37% |
| `first_reported_value` | earlier filing had no value | 25,757 | 0.12% |
| `value_withdrawn` | later filing dropped the value | 24,240 | 0.11% |

The headline revision rate filters to `revision_type = 'value_revision'`. Counting
every row instead overstates restatements by **22.7x** (21,667,233 against 954,391)
as most of the entries are re-assertions of the same value. This distinction at the
fact level shows how 50.8% of facts were re-asserted and but only 3.57% of facts were
revised.

The event count reconciles against the intermediate layer: 45,945,981 versioned rows
minus 24,278,748 authoritative rows is exactly 21,667,233. The mart's `rank()` window
and the `qualify` in `int_facts__authoritative` are independent implementations of the
same grain, so agreeing to the row is a check rather than an identity.

The model name says 'restatement' but this includes both re-assertions (same value repeated)
and revisions (the value is changed).

## Known data-quality limits

Measured, not yet tested for:

- `end_date` spans `1011-12-31` to `2923-12-31` across 29 quarters: 36 rows before 1990
  and 59 after 2030, out of 45,945,981. The low end is filer typos in `ddate`; the high
  end mixes long-dated maturity schedules with typos that are clearly errors (period
  ending 2923). Both tails are small enough that a bounds test would be cheap and catch
  them. No test bounds either side of the 'end_date' field yet.
- Future `end_date` values are why `date_filed < end_date` was rejected as a lookahead
  signal: lease and debt maturity schedules legitimately report period ends years ahead
  of the filing. There's no clean way to separate them from typos.
- 2,638,661 authoritative facts (10.87%) are tagged with a company custom extension
  rather than a standard taxonomy.
