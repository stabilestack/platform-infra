# Plan-only tests against a mocked Sentry provider: no credentials, no API
# calls, nothing created. Run with `tofu test` from modules/sentry-alert.

mock_provider "sentry" {}

variables {
  organization = "example-org"
  project      = "example-app"

  rules = {
    "auth-failure-spike" = {
      title    = "Authentication failure spike"
      severity = "S2"
      conditions = [
        { event_frequency = { value = 20, interval = "5m" } },
      ]
      filters = [
        { tagged_event = { key = "http_method", match = "EQUAL", value = "POST" } },
        { tagged_event = { key = "route", match = "IS_IN", value = "/api/auth,/sign-in" } },
      ]
      actions = [
        { notify_email = { target_type = "IssueOwners", fallthrough_type = "ActiveMembers" } },
      ]
    }
    "new-issue" = {
      title        = "New issue in production"
      environment  = "production"
      action_match = "all"
      conditions = [
        { first_seen_event = {} },
      ]
      actions = [
        { slack_notify_service = { workspace = "123456", channel = "#ops-alerts" } },
      ]
    }
  }
}

run "renders_rules" {
  command = plan

  assert {
    condition     = sentry_issue_alert.this["auth-failure-spike"].name == "[S2] Authentication failure spike"
    error_message = "severity prefixes the rule name"
  }

  assert {
    condition     = sentry_issue_alert.this["new-issue"].name == "New issue in production"
    error_message = "no severity, no prefix"
  }

  assert {
    condition     = sentry_issue_alert.this["auth-failure-spike"].conditions_v2[0].event_frequency.comparison_type == "count"
    error_message = "event_frequency defaults to a count comparison"
  }

  assert {
    condition     = length(sentry_issue_alert.this["auth-failure-spike"].filters_v2) == 2 && sentry_issue_alert.this["new-issue"].filters_v2 == null
    error_message = "filters pass through; no filters plans null"
  }

  assert {
    condition     = sentry_issue_alert.this["auth-failure-spike"].frequency == 30 && sentry_issue_alert.this["auth-failure-spike"].action_match == "any"
    error_message = "defaults: 30-minute frequency, action_match any"
  }

  assert {
    condition     = sentry_issue_alert.this["new-issue"].actions_v2[0].slack_notify_service.channel == "#ops-alerts"
    error_message = "actions pass through"
  }
}

run "two_kinds_in_one_entry_is_rejected" {
  command = plan

  variables {
    rules = {
      "bad" = {
        title = "Ambiguous"
        conditions = [
          { first_seen_event = {}, regression_event = {} },
        ]
        actions = [
          { notify_email = { target_type = "IssueOwners" } },
        ]
      }
    }
  }

  expect_failures = [var.rules]
}
