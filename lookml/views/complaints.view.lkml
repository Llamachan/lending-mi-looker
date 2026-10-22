view: complaints {
  derived_table: {
    sql:
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
      FROM d ;;
  }

  dimension: complaint_id {
    primary_key: yes
    type: number
    sql: ${TABLE}.complaint_id ;;
  }
  dimension: customer_id {
    hidden: yes
    type: number
    sql: ${TABLE}.customer_id ;;
  }
  dimension: product { sql: ${TABLE}.product ;; }
  dimension: category { sql: ${TABLE}.category ;; }
  dimension: channel { sql: ${TABLE}.channel ;; }
  dimension_group: received {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    datatype: date
    sql: ${TABLE}.received_date ;;
  }
  dimension_group: resolved {
    type: time
    timeframes: [raw, date, month]
    datatype: date
    sql: ${TABLE}.resolved_date ;;
  }
  dimension: outcome {
    description: "Blank while the complaint is open"
    sql: ${TABLE}.outcome ;;
  }
  dimension: is_open {
    type: yesno
    sql: ${TABLE}.resolved_date IS NULL ;;
  }
  dimension: is_upheld {
    description: "Upheld or partially upheld"
    type: yesno
    sql: ${outcome} IN ('Upheld', 'Partially upheld') ;;
  }
  dimension: days_to_resolve {
    type: number
    sql: DATE_DIFF(${TABLE}.resolved_date, ${TABLE}.received_date, DAY) ;;
  }
  dimension: resolved_within_8_weeks {
    description: "Closed within 56 days of receipt (the UK FCA final-response deadline)"
    type: yesno
    sql: ${days_to_resolve} <= 56 ;;
  }
  dimension: days_open {
    description: "Age of an open complaint at the data date, 30 Sep 2026"
    type: number
    sql: CASE WHEN ${is_open} THEN DATE_DIFF(DATE '2026-09-30', ${TABLE}.received_date, DAY) END ;;
  }
  dimension: redress_usd {
    type: number
    sql: ${TABLE}.redress_usd ;;
    value_format_name: usd_0
  }
  dimension: referred_to_ombudsman {
    type: yesno
    sql: ${TABLE}.referred_to_ombudsman ;;
  }

  measure: count {
    label: "Complaints"
    type: count
    drill_fields: [complaint_id, received_date, product, category, outcome, days_to_resolve]
  }
  measure: open_count {
    label: "Open Complaints"
    type: count
    filters: [is_open: "yes"]
  }
  measure: closed_count {
    type: count
    filters: [is_open: "no"]
    hidden: yes
  }
  measure: upheld_count {
    type: count
    filters: [is_upheld: "yes"]
    hidden: yes
  }
  measure: upheld_rate {
    label: "Upheld Rate"
    description: "Upheld or partially upheld / closed complaints"
    type: number
    sql: 1.0 * ${upheld_count} / NULLIF(${closed_count}, 0) ;;
    value_format_name: percent_1
  }
  measure: within_8_weeks_count {
    type: count
    filters: [is_open: "no", resolved_within_8_weeks: "yes"]
    hidden: yes
  }
  measure: within_8_weeks_rate {
    label: "Resolved Within 8 Weeks %"
    description: "Closed within 56 days / closed complaints"
    type: number
    sql: 1.0 * ${within_8_weeks_count} / NULLIF(${closed_count}, 0) ;;
    value_format_name: percent_1
  }
  measure: average_days_to_resolve {
    type: average
    sql: ${days_to_resolve} ;;
    value_format_name: decimal_1
  }
  measure: total_redress {
    type: sum
    sql: ${redress_usd} ;;
    value_format_name: usd_0
  }
  measure: ombudsman_referrals {
    type: count
    filters: [referred_to_ombudsman: "yes"]
  }
}
