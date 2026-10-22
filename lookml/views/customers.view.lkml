view: customers {
  derived_table: {
    sql:
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
      FROM base ;;
  }

  dimension: customer_id {
    primary_key: yes
    type: number
    sql: ${TABLE}.customer_id ;;
  }
  dimension: customer_ref {
    label: "Customer Ref"
    sql: ${TABLE}.customer_ref ;;
  }
  dimension: customer_name {
    description: "Personal data. Restricted in Project 2 with an access grant."
    sql: ${TABLE}.customer_name ;;
    # required_access_grants: [can_see_pii]
  }
  dimension: region {
    sql: ${TABLE}.region ;;
    drill_fields: [segment, risk_rating, customer_ref]
  }
  dimension: segment { sql: ${TABLE}.segment ;; }
  dimension: risk_rating {
    description: "KYC customer risk rating: Low, Medium or High"
    sql: ${TABLE}.risk_rating ;;
  }
  dimension: kyc_status { label: "KYC Status" sql: ${TABLE}.kyc_status ;; }
  dimension: is_pep {
    label: "Is PEP"
    description: "Politically exposed person"
    type: yesno
    sql: ${TABLE}.is_pep ;;
  }
  dimension_group: onboard {
    type: time
    timeframes: [date, month, quarter, year]
    datatype: date
    sql: ${TABLE}.onboard_date ;;
  }
  dimension: annual_income_usd {
    type: number
    sql: ${TABLE}.annual_income_usd ;;
    value_format_name: usd_0
  }

  measure: count {
    label: "Customer Count"
    type: count
    drill_fields: [customer_ref, region, segment, risk_rating, kyc_status]
  }
  measure: high_risk_count {
    type: count
    filters: [risk_rating: "High"]
  }
  measure: kyc_verified_count {
    type: count
    filters: [kyc_status: "Verified"]
    hidden: yes
  }
  measure: kyc_verified_rate {
    label: "KYC Verified %"
    type: number
    sql: 1.0 * ${kyc_verified_count} / NULLIF(${count}, 0) ;;
    value_format_name: percent_1
  }
  measure: total_income {
    description: "Sum of customer annual income. Watch this one in the fanout exercise."
    type: sum
    sql: ${annual_income_usd} ;;
    value_format_name: usd_0
  }
}
