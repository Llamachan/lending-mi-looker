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


-- 1. Customers by region and segment
Row	region	segment	customers
1	Hong Kong	Corporate	236
2	Hong Kong	Mass Retail	251
3	Hong Kong	Premier	253
4	Hong Kong	SME	248
5	India	Corporate	254
6	India	Mass Retail	251
7	India	Premier	234
8	India	SME	266
9	Singapore	Corporate	271
10	Singapore	Mass Retail	255
11	Singapore	Premier	216
12	Singapore	SME	243
13	UAE	Corporate	237
14	UAE	Mass Retail	273
15	UAE	Premier	265
16	UAE	SME	236
17	UK	Corporate	220
18	UK	Mass Retail	269
19	UK	Premier	247
20	UK	SME	275

-- 2. Accounts by product and status
Row	product	status	accounts	total_balance
1	Credit Card	Active	1993	5.0598183E7
2	Credit Card	Closed	53	1393689.0
3	Credit Card	Dormant	154	3797396.0
4	Current	Active	2222	5.5749519E7
5	Current	Closed	65	1460755.0
6	Current	Dormant	199	4870445.0
7	Mortgage	Active	517	null
8	Mortgage	Closed	26	null
9	Mortgage	Dormant	48	null
10	Personal Loan	Active	1086	null
11	Personal Loan	Closed	31	null
12	Personal Loan	Dormant	83	null
13	Savings	Active	3191	8.0626072E7
14	Savings	Closed	104	2580327.0
15	Savings	Dormant	221	5639325.0

-- 3. NPL ratio by loan type (open loans only, same rule as the Credit Risk explore)
Row	loan_type	loans	total_outstanding	npl_ratio
1	Mortgage	585	1.04346783E8	0.0416
2	Personal Loan	1189	1.9654952E7	0.0252

-- 4. Expected loss by IFRS 9 stage
Row	ifrs9_stage	expected_loss
1	1	353851.0
2	2	157787.0
3	3	1140089.0

-- 5. NPL ratio by region (the main dashboard tile)
Row	region	npl_ratio
1	Hong Kong	0.0654
2	UAE	0.0523
3	India	0.03
4	Singapore	0.0296
5	UK	0.0189

-- 6. Complaints by category: volume, upheld rate, 8-week resolution rate
Row	category	complaints	open_complaints	upheld_rate	within_8_weeks_rate
1	Underwriting decision	322	27	0.5627	0.9525
2	Customer service	273	23	0.728	0.924
3	Fees and charges	271	20	0.5936	0.9243
4	Arrears and collections	230	14	0.5556	0.9306
5	Affordability and lending	219	13	0.4126	0.9612
6	Fraud and scams	185	13	0.4128	0.9826	

-- 7. Complaints headline numbers
Row	complaints	avg_days_to_resolve	total_redress	ombudsman_referrals
1	1500	27.4	495899	56

-- 8. Fanout check: true total income vs income summed after joining accounts
Row	true_total_income	fanned_out_income
1	554926060	1113008280
