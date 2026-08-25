# Data model

The grain of int_facts__versioned is one row per (cik, tag, period_end, qtrs, adsh). That means: one company's one financial concept, for one period, as asserted by one specific filing. Two filings reporting the same concept for the same period are two rows, not a conflict.
