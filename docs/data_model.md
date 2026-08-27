# Data model

## int_facts__versioned

The grain of int_facts__versioned is one row per (cik, tag, period_end, qtrs, adsh, uom). That means: one company's one financial concept, for one period, as asserted by one specific filing. Unit of meseasure accounts for various currencies. Two filings reporting the same concept for the same period are two rows, not a conflict.

## int_facts__authoritative

The grain of int_facts__authoritative is one row per (cik, tag, period_end, qtrs, uom). This is the same as int_facts__versioned minus the filing distinction. The fields 'version' and 'co_registrant' are exlcluded because in my query across 3 quarters of data, there were no matching grains holding more than 1 distinct value of version or co_registrant, so these were not included in the grain. When two rows have the same grain from different filings, this represents a revision or re-report of the same fact.

For int_facts__authoritative, when two rows have matching grains, the later date_filed is chosen over the earlier, because it is the more current assertion about the same fact. I will use date_accepted from sub as the tiebreaker row, for the case that two values are filed on the same day. I will add the accession_number (unique per filing) as the final backstop so there will always be an ordering and the results will always be deterministic. In my query over 3 quarters, there were no matching grains holding more than 1 distinct value of version or co_registrant so I carrying version/coreg appears
