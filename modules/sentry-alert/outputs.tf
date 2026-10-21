output "rule_ids" {
  description = "Sentry issue-alert rule id per rule key."
  value       = { for k, r in sentry_issue_alert.this : k => r.id }
}
