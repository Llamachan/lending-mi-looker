# Reconciliation: Looker vs SQL

Every governed measure is checked against an independent SQL query
(`sql/02_profiling_and_reconciliation.sql`). Fill in both columns; they must match.

| # | Metric | SQL result | Looker explore and fields | Looker result | Match |
|---|--------|-----------|---------------------------|---------------|-------|
| 1 | Customer count | | Customers and Accounts: Customer Count | | |
| 2 | Total balance by product | | Customers and Accounts: Product, Total Balance | | |
| 3 | NPL ratio by loan type | | Credit Risk: Loan Type, NPL Ratio | | |
| 4 | Expected loss by IFRS 9 stage | | Credit Risk: IFRS 9 Stage, Expected Loss | | |
| 5 | NPL ratio by region | | Credit Risk: Customers Region, NPL Ratio | | |
| 6 | Complaints, open, upheld rate and 8-week rate by category | | Complaints: Category, Complaints, Open Complaints, Upheld Rate, Resolved Within 8 Weeks % | | |
| 7 | Avg days to resolve, total redress, ombudsman referrals | | Complaints: Average Days To Resolve, Total Redress, Ombudsman Referrals | | |
| 8 | Total income (fanout check) | true total: | Customers and Accounts: Total Income with Account Count added | | |

Row 8 is the important one: SQL query 8 shows the inflated number a plain join gives,
and Looker should still return the true total because of symmetric aggregates.
