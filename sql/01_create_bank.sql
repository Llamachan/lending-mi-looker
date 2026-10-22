-- Synthetic bank for practice. Paste into the BigQuery console and click Run.
-- Creates dataset bank_demo with 4 tables (customers, accounts, loans, complaints). Same data as the LookML derived tables.
CREATE SCHEMA IF NOT EXISTS bank_demo;

CREATE OR REPLACE TABLE bank_demo.customers AS
WITH base AS (
  SELECT id,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('a', CAST(id AS STRING))), 1000)) AS r1,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('b', CAST(id AS STRING))), 1000)) AS r2,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('c', CAST(id AS STRING))), 1000)) AS r3,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('d', CAST(id AS STRING))), 1000)) AS r4
  FROM UNNEST(GENERATE_ARRAY(1, 5000)) AS id
)
SELECT
  id AS customer_id,
  CONCAT('CUST-', LPAD(CAST(id AS STRING), 5, '0')) AS customer_ref,
  CONCAT(['Aarav','Priya','Wei','Fatima','Oliver','Mei','Rohan','Sara','James','Ananya'][OFFSET(MOD(r1, 10))],
         ' ',
         ['Sharma','Chen','Khan','Smith','Wong','Iyer','Patel','Lee','Brown','Das'][OFFSET(MOD(r2, 10))]) AS customer_name,
  ['UK','Hong Kong','India','UAE','Singapore'][OFFSET(MOD(r1 + r4, 5))] AS region,
  ['Mass Retail','Premier','SME','Corporate'][OFFSET(MOD(r2 + r3, 4))] AS segment,
  CASE WHEN r3 < 700 THEN 'Low' WHEN r3 < 930 THEN 'Medium' ELSE 'High' END AS risk_rating,
  CASE WHEN r4 < 920 THEN 'Verified' WHEN r4 < 970 THEN 'Pending review' ELSE 'Expired' END AS kyc_status,
  r3 > 985 AS is_pep,
  DATE_SUB(DATE '2026-09-30', INTERVAL MOD(r1 * 7 + r2, 3650) DAY) AS onboard_date,
  20000 + r2 * 180 AS annual_income_usd
FROM base;

CREATE OR REPLACE TABLE bank_demo.accounts AS
WITH base AS (
  SELECT c AS customer_id, c * 10 + k AS account_id
  FROM UNNEST(GENERATE_ARRAY(1, 5000)) AS c
  CROSS JOIN UNNEST(GENERATE_ARRAY(1, 3)) AS k
  WHERE k <= 1 + ABS(MOD(FARM_FINGERPRINT(CONCAT('n', CAST(c AS STRING))), 3))
), r AS (
  SELECT *,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('p', CAST(account_id AS STRING))), 1000)) AS r1,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('q', CAST(account_id AS STRING))), 1000000)) AS r2,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('s', CAST(account_id AS STRING))), 1000)) AS r3
  FROM base
)
SELECT
  account_id,
  customer_id,
  CASE WHEN r1 < 350 THEN 'Savings' WHEN r1 < 600 THEN 'Current' WHEN r1 < 820 THEN 'Credit Card'
       WHEN r1 < 940 THEN 'Personal Loan' ELSE 'Mortgage' END AS product,
  CASE WHEN r1 < 820 THEN ROUND(r2 / 20.0, 2) END AS balance_usd,
  CASE WHEN r3 < 900 THEN 'Active' WHEN r3 < 970 THEN 'Dormant' ELSE 'Closed' END AS status,
  DATE_SUB(DATE '2026-09-30', INTERVAL MOD(r2, 2500) DAY) AS open_date
FROM r;

CREATE OR REPLACE TABLE bank_demo.loans AS
WITH l AS (
  SELECT a.account_id AS loan_id, a.customer_id, a.product AS loan_type, a.open_date AS disbursed_date,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('L', CAST(a.account_id AS STRING))), 1000)) AS r1,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('M', CAST(a.account_id AS STRING))), 1000)) AS r2
  FROM bank_demo.accounts AS a
  WHERE a.product IN ('Personal Loan', 'Mortgage')
), d AS (
  SELECT *,
    CASE WHEN r2 < 850 THEN 0
         WHEN r2 < 930 THEN 1 + MOD(r1, 30)
         WHEN r2 < 970 THEN 31 + MOD(r1, 60)
         ELSE 91 + MOD(r1 * 3, 275) END AS days_past_due,
    CASE WHEN loan_type = 'Mortgage' THEN 50000 + r1 * 450 ELSE 1000 + r1 * 49 END AS principal
  FROM l
)
SELECT
  loan_id, customer_id, loan_type, disbursed_date, principal,
  ROUND(principal * (0.3 + MOD(r1 * 7, 700) / 1000.0), 2) AS outstanding,
  ROUND(CASE WHEN loan_type = 'Mortgage' THEN 3.5 + MOD(r1, 25) / 10.0 ELSE 9 + MOD(r1, 90) / 10.0 END, 2) AS interest_rate,
  CASE WHEN loan_type = 'Mortgage' THEN 240 ELSE 36 END AS term_months,
  days_past_due,
  CASE WHEN days_past_due > 90 THEN 3 WHEN days_past_due > 30 THEN 2 ELSE 1 END AS ifrs9_stage,
  CASE WHEN days_past_due > 90 THEN 1.0 WHEN days_past_due > 30 THEN 0.15 ELSE 0.012 END AS pd,
  CASE WHEN loan_type = 'Mortgage' THEN 0.20 ELSE 0.55 END AS lgd,
  CASE WHEN days_past_due > 180 AND MOD(r1, 4) = 0 THEN 'Written Off' ELSE 'Open' END AS status
FROM d;

CREATE OR REPLACE TABLE bank_demo.complaints AS
WITH base AS (
  SELECT id AS complaint_id,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('ca', CAST(id AS STRING))), 1000)) AS r1,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('cb', CAST(id AS STRING))), 1000)) AS r2,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('cc', CAST(id AS STRING))), 1000)) AS r3,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('cd', CAST(id AS STRING))), 1000)) AS r4,
    ABS(MOD(FARM_FINGERPRINT(CONCAT('ce', CAST(id AS STRING))), 1000)) AS r5
  FROM UNNEST(GENERATE_ARRAY(1, 1500)) AS id
), c AS (
  SELECT *,
    1 + MOD(r1 * 7 + r2, 5000) AS customer_id,
    CASE WHEN r1 < 300 THEN 'Mortgage' WHEN r1 < 550 THEN 'Personal Loan'
         WHEN r1 < 800 THEN 'Credit Card' ELSE 'Current Account' END AS product,
    CASE WHEN r2 < 220 THEN 'Underwriting decision'
         WHEN r2 < 380 THEN 'Affordability and lending'
         WHEN r2 < 560 THEN 'Fees and charges'
         WHEN r2 < 700 THEN 'Arrears and collections'
         WHEN r2 < 880 THEN 'Customer service'
         ELSE 'Fraud and scams' END AS category,
    ['Phone', 'Branch', 'Online', 'Email'][OFFSET(MOD(r3, 4))] AS channel,
    DATE_SUB(DATE '2026-09-30', INTERVAL MOD(r1 * 3 + r4, 365) DAY) AS received_date,
    CASE WHEN r3 < 780 THEN 1 + MOD(r4, 40)
         WHEN r3 < 930 THEN 41 + MOD(r4, 15)
         ELSE 57 + MOD(r4, 60) END AS days_needed
  FROM base
), d AS (
  SELECT *,
    IF(DATE_ADD(received_date, INTERVAL days_needed DAY) > DATE '2026-09-30', NULL,
       DATE_ADD(received_date, INTERVAL days_needed DAY)) AS resolved_date,
    CASE category
      WHEN 'Underwriting decision' THEN 350
      WHEN 'Affordability and lending' THEN 300
      WHEN 'Fees and charges' THEN 450
      WHEN 'Arrears and collections' THEN 400
      WHEN 'Customer service' THEN 550
      ELSE 250 END AS uphold_threshold
  FROM c
)
SELECT
  complaint_id, customer_id, product, category, channel, received_date, resolved_date,
  CASE WHEN resolved_date IS NULL THEN NULL
       WHEN r5 < uphold_threshold THEN 'Upheld'
       WHEN r5 < uphold_threshold + 150 THEN 'Partially upheld'
       ELSE 'Not upheld' END AS outcome,
  CASE WHEN resolved_date IS NULL THEN 0
       WHEN r5 < uphold_threshold THEN 50 + MOD(r4 * 13, 1500)
       WHEN r5 < uphold_threshold + 150 THEN 25 + MOD(r4 * 7, 500)
       ELSE 0 END AS redress_usd,
  resolved_date IS NOT NULL AND r5 >= uphold_threshold + 150 AND r3 > 880 AS referred_to_ombudsman
FROM d;

-- Check it worked:
SELECT 'customers' AS t, COUNT(*) AS n FROM bank_demo.customers UNION ALL
SELECT 'accounts', COUNT(*) FROM bank_demo.accounts UNION ALL
SELECT 'loans', COUNT(*) FROM bank_demo.loans UNION ALL
SELECT 'complaints', COUNT(*) FROM bank_demo.complaints;
