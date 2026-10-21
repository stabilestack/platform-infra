# Sentry issue-alert rules as code. Rule names get an "[S<n>] " prefix from
# `severity`, so the response SLA is visible in every notification subject.

resource "sentry_issue_alert" "this" {
  for_each = var.rules

  organization = var.organization
  project      = var.project
  name         = each.value.severity == null ? each.value.title : "[${each.value.severity}] ${each.value.title}"
  environment  = each.value.environment
  frequency    = each.value.frequency_minutes
  action_match = each.value.action_match
  filter_match = each.value.filter_match
  owner        = each.value.owner

  conditions_v2 = each.value.conditions
  filters_v2    = length(each.value.filters) == 0 ? null : each.value.filters
  actions_v2    = each.value.actions

  lifecycle {
    prevent_destroy = true
  }
}
