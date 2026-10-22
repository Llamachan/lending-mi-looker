connection: "PASTE_YOUR_CONNECTION_NAME"
# In a lab, open the existing model file and copy its connection name here.

include: "/views/*.view.lkml"

# Hides personal data unless the user's pii_access attribute is "yes".
# Create the attribute first (Admin > User Attributes), then uncomment
# required_access_grants on customers.customer_name.
# access_grant: can_see_pii {
#   user_attribute: pii_access
#   allowed_values: ["yes"]
# }

datagroup: daily_refresh {
  sql_trigger: SELECT CURRENT_DATE() ;;
  max_cache_age: "24 hours"
}
persist_with: daily_refresh

explore: customers {
  label: "Customers and Accounts"
  join: accounts {
    type: left_outer
    relationship: one_to_many
    sql_on: ${customers.customer_id} = ${accounts.customer_id} ;;
  }
  join: customer_loan_summary {
    type: left_outer
    relationship: one_to_one
    sql_on: ${customers.customer_id} = ${customer_loan_summary.customer_id} ;;
  }
}

explore: loans {
  label: "Credit Risk"
  sql_always_where: ${loans.status} = 'Open' ;;
  # Row-level security. Needs a "region" user attribute (Admin > User Attributes).
  # Uncomment once the attribute exists, then validate.
  # access_filter: {
  #   field: customers.region
  #   user_attribute: region
  # }
  join: customers {
    type: left_outer
    relationship: many_to_one
    sql_on: ${loans.customer_id} = ${customers.customer_id} ;;
  }
}

explore: complaints {
  label: "Complaints"
  join: customers {
    type: left_outer
    relationship: many_to_one
    sql_on: ${complaints.customer_id} = ${customers.customer_id} ;;
  }
}

test: customer_count_survives_join {
  explore_source: customers {
    column: customer_count { field: customers.count }
    column: account_count { field: accounts.count }
  }
  assert: still_5000_customers {
    expression: ${customers.count} = 5000 ;;
  }
}

test: loan_id_is_unique {
  explore_source: loans {
    column: loan_id { field: loans.loan_id }
    column: loan_count { field: loans.count }
    sorts: [loans.count: desc]
    limit: 1
  }
  assert: no_duplicate_loans {
    expression: ${loans.count} = 1 ;;
  }
}

test: complaint_id_is_unique {
  explore_source: complaints {
    column: complaint_id { field: complaints.complaint_id }
    column: complaint_count { field: complaints.count }
    sorts: [complaints.count: desc]
    limit: 1
  }
  assert: no_duplicate_complaints {
    expression: ${complaints.count} = 1 ;;
  }
}
