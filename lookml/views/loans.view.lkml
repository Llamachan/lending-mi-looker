view: loans {
  derived_table: {
    sql:
      WITH l AS (
        SELECT a.account_id AS loan_id, a.customer_id, a.product AS loan_type, a.open_date AS disbursed_date,
          ABS(MOD(FARM_FINGERPRINT(CONCAT('L', CAST(a.account_id AS STRING))), 1000)) AS r1,
          ABS(MOD(FARM_FINGERPRINT(CONCAT('M', CAST(a.account_id AS STRING))), 1000)) AS r2
        FROM ${accounts.SQL_TABLE_NAME} AS a
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
      FROM d ;;
  }

  dimension: loan_id {
    primary_key: yes
    type: number
    sql: ${TABLE}.loan_id ;;
  }
  dimension: customer_id {
    hidden: yes
    type: number
    sql: ${TABLE}.customer_id ;;
  }
  dimension: loan_type { sql: ${TABLE}.loan_type ;; }
  dimension: status { sql: ${TABLE}.status ;; }
  dimension_group: disbursed {
    type: time
    timeframes: [raw, date, month, quarter, year]
    datatype: date
    sql: ${TABLE}.disbursed_date ;;
  }
  dimension: principal {
    type: number
    sql: ${TABLE}.principal ;;
    value_format_name: usd_0
  }
  dimension: principal_band {
    type: tier
    tiers: [10000, 50000, 100000, 250000]
    style: integer
    sql: ${principal} ;;
  }
  dimension: outstanding {
    type: number
    sql: ${TABLE}.outstanding ;;
    value_format_name: usd_0
  }
  dimension: interest_rate {
    description: "Annual rate in percent, e.g. 9.5"
    type: number
    sql: ${TABLE}.interest_rate ;;
  }
  dimension: days_past_due {
    type: number
    sql: ${TABLE}.days_past_due ;;
  }
  dimension: dpd_bucket {
    label: "DPD Bucket"
    case: {
      when: { sql: ${days_past_due} = 0 ;; label: "Current" }
      when: { sql: ${days_past_due} BETWEEN 1 AND 30 ;; label: "1-30 DPD" }
      when: { sql: ${days_past_due} BETWEEN 31 AND 90 ;; label: "31-90 DPD" }
      else: "90+ DPD (NPL)"
    }
  }
  dimension: is_npl {
    label: "Is NPL"
    description: "More than 90 days past due"
    type: yesno
    sql: ${days_past_due} > 90 ;;
  }
  dimension: ifrs9_stage {
    label: "IFRS 9 Stage"
    type: number
    sql: ${TABLE}.ifrs9_stage ;;
  }
  dimension: pd { label: "PD" type: number sql: ${TABLE}.pd ;; value_format_name: percent_1 }
  dimension: lgd { label: "LGD" type: number sql: ${TABLE}.lgd ;; value_format_name: percent_0 }

  parameter: rate_shock_bps {
    label: "Rate shock (bps)"
    type: number
    default_value: "0"
  }
  dimension: stressed_rate {
    type: number
    sql: ${interest_rate} + {% parameter rate_shock_bps %} / 100.0 ;;
  }

  measure: count {
    label: "Loan Count"
    type: count
    drill_fields: [loan_id, loan_type, outstanding, days_past_due, ifrs9_stage]
  }
  measure: total_outstanding {
    type: sum
    sql: ${outstanding} ;;
    value_format_name: usd_0
  }
  measure: npl_outstanding {
    label: "NPL Outstanding"
    type: sum
    sql: ${outstanding} ;;
    filters: [is_npl: "yes"]
    value_format_name: usd_0
  }
  measure: npl_ratio {
    label: "NPL Ratio"
    description: "NPL outstanding / total outstanding. NPL = more than 90 DPD."
    type: number
    sql: 1.0 * ${npl_outstanding} / NULLIF(${total_outstanding}, 0) ;;
    value_format_name: percent_2
  }
  measure: expected_loss {
    description: "Simplified EL = outstanding x PD x LGD"
    type: sum
    sql: ${outstanding} * ${pd} * ${lgd} ;;
    value_format_name: usd_0
  }
  measure: rate_x_balance {
    hidden: yes
    type: sum
    sql: ${outstanding} * ${interest_rate} ;;
  }
  measure: weighted_avg_rate {
    label: "Weighted Avg Rate (%)"
    type: number
    sql: ${rate_x_balance} / NULLIF(${total_outstanding}, 0) ;;
    value_format_name: decimal_2
  }
  measure: stressed_annual_interest {
    type: sum
    sql: ${outstanding} * ${stressed_rate} / 100.0 ;;
    value_format_name: usd_0
  }
}
