# Retail Lending and Complaints MI in Looker

A LookML model of a synthetic retail bank, built to practise governed lending and
complaints MI in Looker. All data is generated; no real customer data is used.

## What it models

| Explore | Base view | Joins | Used for |
|---------|-----------|-------|----------|
| Customers and Accounts | customers | accounts (one_to_many), customer_loan_summary | Customer base, balances, KYC |
| Credit Risk | loans | customers (many_to_one) | NPL, arrears, IFRS 9, expected loss |
| Complaints | complaints | customers (many_to_one) | Volumes, upheld rate, time to resolve, redress |

Data: 5,000 customers, about 10,000 accounts, about 1,800 loans (mortgages and
personal loans) and 1,500 complaints over twelve months, as of 30 Sep 2026.

## Metric definitions

| Measure | Definition |
|---------|------------|
| NPL ratio | Outstanding on loans more than 90 days past due / total outstanding (open loans) |
| DPD bucket | Current, 1-30, 31-90, 90+ days past due |
| IFRS 9 stage | 1 performing, 2 more than 30 DPD, 3 more than 90 DPD |
| Expected loss | Outstanding x PD x LGD (simplified) |
| Weighted average rate | Sum(outstanding x rate) / sum(outstanding) |
| Upheld rate | Upheld or partially upheld / closed complaints |
| Resolved within 8 weeks | Closed within 56 days of receipt / closed complaints |
| Days open | Age of an open complaint at the data date |

Each metric is defined once in LookML and reconciled against independent SQL
(see `docs/reconciliation.md`).

## Design choices

- Every view has a primary key and every join a declared relationship, so Looker
  uses symmetric aggregates and customer-level measures don't inflate when
  accounts are joined (fanout). A LookML data test guards this.
- Views generate their data as derived tables, so the project runs in any Looker
  instance connected to BigQuery without loading tables first.
- Written-off loans are excluded from the Credit Risk explore with `sql_always_where`.
- Row-level security by region (`access_filter`) and a personal-data access grant
  are included, ready to switch on once the user attributes exist.
- A `rate_shock_bps` parameter supports a simple interest-rate stress test.

## How to run

1. **BigQuery (optional, for SQL practice):** run `sql/01_create_bank.sql` in the
   BigQuery console (sandbox is fine). It creates dataset `bank_demo`.
2. **Looker:** in a Looker instance or Google Skills lab with Development Mode,
   add the files under `lookml/`, set `connection:` in the model to the instance's
   BigQuery connection, then Validate LookML and Run LookML Tests.
3. Run `sql/02_profiling_and_reconciliation.sql` and fill in `docs/reconciliation.md`.

## Structure

```
lookml/
  banking.model.lkml          model, explores, datagroup, data tests
  views/                      customers, accounts, loans,
                              customer_loan_summary (derived), complaints
  dashboards/                 LookML dashboards (Get LookML from the UI)
sql/                          bank generator and reconciliation queries
docs/                         reconciliation results, screenshots
```

## Dashboards

- **Credit Risk MI:** NPL ratio, total outstanding, expected loss; NPL ratio by
  region; arrears profile by DPD bucket and loan type; IFRS 9 stage table;
  rate stress test.
- **Complaints MI:** received and open complaints, upheld rate, 8-week
  resolution rate, trend by product, categories by upheld rate, aged open
  complaints, redress by category.

Screenshots: `docs/screenshots/`.

## Status

- [ ] Model validates, explores return results
- [ ] Data tests pass
- [ ] Reconciliation complete
- [ ] Credit Risk MI dashboard
- [ ] Complaints MI dashboard
- [ ] Access filter demonstrated
