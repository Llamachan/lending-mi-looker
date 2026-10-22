view: customer_loan_summary {
  derived_table: {
    sql:
      SELECT customer_id,
             COUNT(*)           AS loan_count,
             SUM(outstanding)   AS total_outstanding,
             MAX(days_past_due) AS worst_dpd
      FROM ${loans.SQL_TABLE_NAME}
      WHERE status = 'Open'
      GROUP BY customer_id ;;
  }

  dimension: customer_id {
    primary_key: yes
    hidden: yes
    type: number
    sql: ${TABLE}.customer_id ;;
  }
  dimension: loan_count {
    type: number
    sql: ${TABLE}.loan_count ;;
  }
  dimension: customer_outstanding {
    type: number
    sql: ${TABLE}.total_outstanding ;;
    value_format_name: usd_0
  }
  dimension: worst_dpd {
    label: "Worst DPD"
    type: number
    sql: ${TABLE}.worst_dpd ;;
  }
  dimension: has_any_npl {
    label: "Has Any NPL"
    description: "Customer has at least one open loan more than 90 days past due"
    type: yesno
    sql: ${worst_dpd} > 90 ;;
  }
}
