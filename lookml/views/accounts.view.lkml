view: accounts {
  derived_table: {
    sql:
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
      FROM r ;;
  }

  dimension: account_id {
    primary_key: yes
    type: number
    sql: ${TABLE}.account_id ;;
  }
  dimension: customer_id {
    hidden: yes
    type: number
    sql: ${TABLE}.customer_id ;;
  }
  dimension: product { sql: ${TABLE}.product ;; }
  dimension: status { sql: ${TABLE}.status ;; }
  dimension: balance_usd {
    description: "Deposit and card balances. Loan balances live in loans.outstanding."
    type: number
    sql: ${TABLE}.balance_usd ;;
    value_format_name: usd
  }
  dimension_group: open {
    type: time
    timeframes: [date, month, year]
    datatype: date
    sql: ${TABLE}.open_date ;;
  }

  measure: count {
    label: "Account Count"
    type: count
    drill_fields: [account_id, product, status, balance_usd]
  }
  measure: total_balance {
    type: sum
    sql: ${balance_usd} ;;
    value_format_name: usd_0
  }
  measure: average_balance {
    type: average
    sql: ${balance_usd} ;;
    value_format_name: usd_0
  }
  measure: dormant_count {
    type: count
    filters: [status: "Dormant"]
    hidden: yes
  }
  measure: dormant_rate {
    type: number
    sql: 1.0 * ${dormant_count} / NULLIF(${count}, 0) ;;
    value_format_name: percent_1
  }
}
