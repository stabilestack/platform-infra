organization = "example-org"
project      = "example-app"

rules = {
  "critical-route-errors" = {
    title       = "Critical route errors"
    severity    = "S2"
    environment = "production"
    conditions  = [{ event_frequency = { value = 3, interval = "5m" } }]
    filters     = [{ tagged_event = { key = "route", match = "STARTS_WITH", value = "/api/v1/orders" } }]
    actions     = [{ notify_email = { target_type = "IssueOwners", fallthrough_type = "ActiveMembers" } }]
  }
  "new-issue" = {
    title       = "New issue in production"
    severity    = "S3"
    environment = "production"
    conditions  = [{ first_seen_event = {} }]
    actions     = [{ notify_email = { target_type = "IssueOwners", fallthrough_type = "ActiveMembers" } }]
  }
}
