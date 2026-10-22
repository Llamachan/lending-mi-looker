-- Run each query in BigQuery and copy the result into docs/reconciliation.md.
-- The Looker numbers must match these.

-- 1. Customers by region and segment
SELECT region, segment, COUNT(*) AS customers
FROM bank_demo.customers
GROUP BY 1, 2
ORDER BY 1, 2;

-- 2. Accounts by product and status
SELECT product, status, COUNT(*) AS accounts, ROUND(SUM(balance_usd), 0) AS total_balance
FROM bank_demo.accounts
GROUP BY 1, 2
ORDER BY 1, 2;

-- 3. NPL ratio by loan type (open loans only, same rule as the Credit Risk explore)
SELECT loan_type,
       COUNT(*) AS loans,
       ROUND(SUM(outstanding), 0) AS total_outstanding,
       ROUND(SUM(IF(days_past_due > 90, outstanding, 0)) / SUM(outstanding), 4) AS npl_ratio
FROM bank_demo.loans
WHERE status = 'Open'
GROUP BY 1;

-- 4. Expected loss by IFRS 9 stage
SELECT ifrs9_stage, ROUND(SUM(outstanding * pd * lgd), 0) AS expected_loss
FROM bank_demo.loans
WHERE status = 'Open'
GROUP BY 1
ORDER BY 1;

-- 5. NPL ratio by region (the main dashboard tile)
SELECT c.region,
       ROUND(SUM(IF(l.days_past_due > 90, l.outstanding, 0)) / SUM(l.outstanding), 4) AS npl_ratio
FROM bank_demo.loans l
LEFT JOIN bank_demo.customers c USING (customer_id)
WHERE l.status = 'Open'
GROUP BY 1
ORDER BY 2 DESC;

-- 6. Complaints by category: volume, upheld rate, 8-week resolution rate
SELECT category,
       COUNT(*) AS complaints,
       COUNTIF(resolved_date IS NULL) AS open_complaints,
       ROUND(COUNTIF(outcome IN ('Upheld', 'Partially upheld')) / COUNTIF(resolved_date IS NOT NULL), 4) AS upheld_rate,
       ROUND(COUNTIF(DATE_DIFF(resolved_date, received_date, DAY) <= 56) / COUNTIF(resolved_date IS NOT NULL), 4) AS within_8_weeks_rate
FROM bank_demo.complaints
GROUP BY 1
ORDER BY 2 DESC;

-- 7. Complaints headline numbers
SELECT COUNT(*) AS complaints,
       ROUND(AVG(DATE_DIFF(resolved_date, received_date, DAY)), 1) AS avg_days_to_resolve,
       SUM(redress_usd) AS total_redress,
       COUNTIF(referred_to_ombudsman) AS ombudsman_referrals
FROM bank_demo.complaints;

-- 8. Fanout check: true total income vs income summed after joining accounts
SELECT
  (SELECT SUM(annual_income_usd) FROM bank_demo.customers) AS true_total_income,
  (SELECT SUM(c.annual_income_usd)
     FROM bank_demo.customers c
     JOIN bank_demo.accounts a USING (customer_id)) AS fanned_out_income;
