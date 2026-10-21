# Plan-only tests against a mocked Datadog provider: no credentials, no API
# calls, nothing created. Run with `tofu test` from modules/slo.

mock_provider "datadog" {
  override_resource {
    target = datadog_service_level_objective.this
    values = { id = "slo0000000000000000000000000000" }
  }
}

variables {
  journeys_contract_version = 1
  service                   = "example-app"
  query_tags                = { env = "production" }
  page_notify               = ["@slack-ops-alerts-critical"]
  ticket_notify             = ["@slack-ops-alerts"]
  validate_queries          = false

  slos = {
    "AUTH.03" = {
      journey_id  = "AUTH.03"
      title       = "Sign in"
      description = null
      tier        = "P0"
      severity    = "S1"
      owner       = "Platform"
      sli = {
        kind           = "ratio"
        good           = { metric = "auth.sign_in.attempt", tags = { outcome = "success" } }
        total          = { metric = "auth.sign_in.attempt", tags = {} }
        lag            = null
        within_seconds = null
      }
      target      = 99.5
      window_days = 28
      burn_alerts = [
        { action = "page", burn_rate = 14.4, long_window_minutes = 60, short_window_minutes = 5 },
        { action = "ticket", burn_rate = 6, long_window_minutes = 360, short_window_minutes = 30 },
      ]
      runbook_path = "docs/runbooks/sign-in.md"
      runbook_url  = "https://github.com/example-org/example-app/blob/main/docs/runbooks/sign-in.md"
    }
    "NOTES.02" = {
      journey_id  = "NOTES.02"
      title       = "Edit a note"
      description = "Saves an edit."
      tier        = "P1"
      severity    = null
      owner       = null
      sli = {
        kind           = "ratio"
        good           = { metric = "notes.update", tags = { outcome = "success" } }
        total          = { metric = "notes.update", tags = {} }
        lag            = null
        within_seconds = null
      }
      target      = 99
      window_days = 90
      burn_alerts = [
        { action = "ticket", burn_rate = 6, long_window_minutes = 360, short_window_minutes = 30 },
      ]
      runbook_path = null
      runbook_url  = null
    }
    "BG.SYNC.01" = {
      journey_id  = "BG.SYNC.01"
      title       = "Provider event synced"
      description = null
      tier        = "P0"
      severity    = "S2"
      owner       = null
      sli = {
        kind           = "freshness"
        good           = null
        total          = { metric = "sync.triggered", tags = { source = "webhook" } }
        lag            = { metric = "sync.lag_seconds", tags = {} }
        within_seconds = 900
      }
      target      = 99.5
      window_days = 30
      burn_alerts = [
        { action = "page", burn_rate = 14.4, long_window_minutes = 60, short_window_minutes = 5 },
        { action = "ticket", burn_rate = 6, long_window_minutes = 360, short_window_minutes = 30 },
      ]
      runbook_path = null
      runbook_url  = null
    }
  }
}

run "maps_contracts_to_slos_and_burn_monitors" {
  command = plan

  assert {
    condition     = datadog_service_level_objective.this["AUTH.03"].thresholds[0].timeframe == "30d"
    error_message = "the contracts' 28-day default must map to 30d"
  }

  assert {
    condition     = datadog_service_level_objective.this["NOTES.02"].thresholds[0].timeframe == "90d"
    error_message = "a supported window must pass through unchanged"
  }

  assert {
    condition     = output.timeframes["AUTH.03"].remapped && !output.timeframes["NOTES.02"].remapped
    error_message = "remapped flag is wrong"
  }

  assert {
    condition     = datadog_service_level_objective.this["AUTH.03"].query[0].numerator == "sum:auth.sign_in.attempt{env:production,outcome:success}.as_count()"
    error_message = "ratio numerator: ${datadog_service_level_objective.this["AUTH.03"].query[0].numerator}"
  }

  assert {
    condition     = datadog_service_level_objective.this["AUTH.03"].query[0].denominator == "sum:auth.sign_in.attempt{env:production}.as_count()"
    error_message = "ratio denominator: ${datadog_service_level_objective.this["AUTH.03"].query[0].denominator}"
  }

  assert {
    condition     = datadog_service_level_objective.this["BG.SYNC.01"].query[0].numerator == "count(v: v<=900):sync.lag_seconds{env:production}.as_count()"
    error_message = "freshness numerator: ${datadog_service_level_objective.this["BG.SYNC.01"].query[0].numerator}"
  }

  assert {
    condition     = datadog_service_level_objective.this["BG.SYNC.01"].query[0].denominator == "sum:sync.triggered{env:production,source:webhook}.as_count()"
    error_message = "freshness denominator: ${datadog_service_level_objective.this["BG.SYNC.01"].query[0].denominator}"
  }

  assert {
    condition     = toset(keys(datadog_monitor.burn_rate)) == toset(["AUTH.03/page", "AUTH.03/ticket", "NOTES.02/ticket", "BG.SYNC.01/page", "BG.SYNC.01/ticket"])
    error_message = "unexpected burn monitor set: ${join(", ", keys(datadog_monitor.burn_rate))}"
  }

  assert {
    condition     = datadog_monitor.burn_rate["AUTH.03/page"].query == "burn_rate(\"slo0000000000000000000000000000\").over(\"30d\").long_window(\"1h\").short_window(\"5m\") > 14.4"
    error_message = "page query: ${datadog_monitor.burn_rate["AUTH.03/page"].query}"
  }

  assert {
    condition     = datadog_monitor.burn_rate["NOTES.02/ticket"].query == "burn_rate(\"slo0000000000000000000000000000\").over(\"90d\").long_window(\"6h\").short_window(\"30m\") > 6"
    error_message = "ticket query: ${datadog_monitor.burn_rate["NOTES.02/ticket"].query}"
  }

  assert {
    condition     = datadog_monitor.burn_rate["AUTH.03/page"].type == "slo alert"
    error_message = "burn monitors must be slo alert monitors"
  }

  assert {
    condition     = strcontains(datadog_monitor.burn_rate["AUTH.03/page"].message, "@slack-ops-alerts-critical") && !strcontains(datadog_monitor.burn_rate["AUTH.03/ticket"].message, "@slack-ops-alerts-critical")
    error_message = "page alerts go to page_notify, ticket alerts to ticket_notify only"
  }

  assert {
    condition     = strcontains(datadog_monitor.burn_rate["AUTH.03/page"].message, "Runbook: https://github.com/example-org/example-app/blob/main/docs/runbooks/sign-in.md")
    error_message = "the alert must carry the runbook link"
  }

  assert {
    condition     = datadog_monitor.burn_rate["AUTH.03/page"].priority == "1" && datadog_monitor.burn_rate["NOTES.02/ticket"].priority == "4"
    error_message = "priority comes from severity, else the action default"
  }

  assert {
    condition     = contains(datadog_service_level_objective.this["AUTH.03"].tags, "journey:auth.03") && contains(datadog_service_level_objective.this["AUTH.03"].tags, "owner:platform")
    error_message = "tags must be lowercased journey/owner tags"
  }
}

run "p1_page_alert_is_rejected" {
  command = plan

  variables {
    slos = {
      "NOTES.02" = {
        journey_id  = "NOTES.02"
        title       = "Edit a note"
        description = null
        tier        = "P1"
        severity    = null
        owner       = null
        sli = {
          kind           = "ratio"
          good           = { metric = "notes.update", tags = {} }
          total          = { metric = "notes.update", tags = {} }
          lag            = null
          within_seconds = null
        }
        target      = 99
        window_days = 30
        burn_alerts = [
          { action = "page", burn_rate = 14.4, long_window_minutes = 60, short_window_minutes = 5 },
        ]
        runbook_path = null
        runbook_url  = null
      }
    }
  }

  expect_failures = [var.slos]
}

run "unknown_contract_version_is_rejected" {
  command = plan

  variables {
    journeys_contract_version = 2
  }

  expect_failures = [var.journeys_contract_version]
}

run "unmapped_window_is_rejected" {
  command = plan

  variables {
    window_remaps = {}
  }

  # 28 days is unsupported and, with the default remap removed, unmapped.
  expect_failures = [datadog_service_level_objective.this]
}

run "empty_contract_plans_nothing" {
  command = plan

  variables {
    slos = {}
  }

  assert {
    condition     = length(datadog_service_level_objective.this) == 0 && length(datadog_monitor.burn_rate) == 0
    error_message = "no contracts, no resources"
  }
}
