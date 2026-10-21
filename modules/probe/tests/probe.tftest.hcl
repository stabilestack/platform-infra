# Plan-only tests against mocked Datadog and Cloudflare providers: no
# credentials, no API calls, nothing created. Run with `tofu test` from modules/probe.

mock_provider "datadog" {}
mock_provider "cloudflare" {}

variables {
  journeys_contract_version = 1
  service                   = "example-app"
  cloudflare_account_id     = "0123456789abcdef0123456789abcdef"
  datadog_api_key           = "test-key"
  probe_request_headers     = { "AUTH.03" = { authorization = "Bearer probe-user" } }
  page_notify               = ["@slack-ops-alerts-critical"]
  ticket_notify             = ["@slack-ops-alerts"]
  validate_queries          = false

  probes = {
    "AUTH.03" = {
      journey_id          = "AUTH.03"
      title               = "Sign in"
      tier                = "P0"
      severity            = "S1"
      kind                = "api"
      interval_minutes    = 5
      stale_after_minutes = 15
      url                 = "https://app.example.com/api/probe/sign-in"
      method              = "POST"
      expect_status       = [200]
      spec                = null
      runbook_url         = "https://github.com/example-org/example-app/blob/main/docs/runbooks/sign-in.md"
    }
    "AUTH.01" = {
      journey_id          = "AUTH.01"
      title               = "Sign up"
      tier                = "P0"
      severity            = null
      kind                = "browser"
      interval_minutes    = 60
      stale_after_minutes = 150
      url                 = null
      method              = null
      expect_status       = null
      spec                = "e2e/probes/sign-up.spec.ts"
      runbook_url         = null
    }
    "NOTES.03" = {
      journey_id          = "NOTES.03"
      title               = "Share a note"
      tier                = "P1"
      severity            = "S3"
      kind                = "api"
      interval_minutes    = 5
      stale_after_minutes = 15
      url                 = "https://app.example.com/share/probe"
      method              = "GET"
      expect_status       = [200, 304]
      spec                = null
      runbook_url         = null
    }
  }
}

run "runner_and_monitors" {
  command = plan

  assert {
    condition     = length(cloudflare_workers_script.runner) == 1 && cloudflare_workers_script.runner[0].script_name == "example-app-journey-probes"
    error_message = "one runner Worker per module instance"
  }

  assert {
    condition     = cloudflare_workers_cron_trigger.runner[0].schedules[0].cron == "*/5 * * * *"
    error_message = "runner ticks every 5 minutes"
  }

  assert {
    condition = jsondecode(one([for b in cloudflare_workers_script.runner[0].bindings : b.json if b.name == "PROBES"])) == {
      "AUTH.03"  = { url = "https://app.example.com/api/probe/sign-in", method = "POST", expect_status = [200], interval_minutes = 5 }
      "NOTES.03" = { url = "https://app.example.com/share/probe", method = "GET", expect_status = [200, 304], interval_minutes = 5 }
    }
    error_message = "the runner gets api probes only, with just what it needs to run them"
  }

  assert {
    condition     = toset(keys(datadog_monitor.stale)) == toset(["AUTH.01", "AUTH.03", "NOTES.03"])
    error_message = "every probe, api or browser, gets a staleness monitor"
  }

  assert {
    condition     = datadog_monitor.stale["AUTH.01"].no_data_timeframe == 150 && datadog_monitor.stale["AUTH.03"].no_data_timeframe == 15
    error_message = "staleness = stale_after_minutes"
  }

  assert {
    condition     = datadog_monitor.stale["AUTH.03"].query == "max(last_5m):max:journey.probe.success{journey:auth.03,service:example-app,env:production} < 0"
    error_message = "stale query: ${datadog_monitor.stale["AUTH.03"].query}"
  }

  assert {
    condition     = datadog_monitor.failing["AUTH.03"].query == "max(last_15m):max:journey.probe.success{journey:auth.03,service:example-app,env:production} < 1"
    error_message = "failing query: ${datadog_monitor.failing["AUTH.03"].query}"
  }

  assert {
    condition     = strcontains(datadog_monitor.failing["AUTH.03"].message, "@slack-ops-alerts-critical") && !strcontains(datadog_monitor.failing["NOTES.03"].message, "@slack-ops-alerts-critical")
    error_message = "P0 probe failures page; P1 never pages"
  }

  assert {
    condition     = !strcontains(datadog_monitor.stale["AUTH.03"].message, "@slack-ops-alerts-critical")
    error_message = "staleness always tickets"
  }
}

run "browser_only_needs_no_runner" {
  command = plan

  variables {
    datadog_api_key = null
    probes = {
      "AUTH.01" = {
        journey_id          = "AUTH.01"
        title               = "Sign up"
        tier                = "P0"
        severity            = null
        kind                = "browser"
        interval_minutes    = 60
        stale_after_minutes = 150
        url                 = null
        method              = null
        expect_status       = null
        spec                = "e2e/probes/sign-up.spec.ts"
        runbook_url         = null
      }
    }
  }

  assert {
    condition     = length(cloudflare_workers_script.runner) == 0 && length(cloudflare_workers_cron_trigger.runner) == 0
    error_message = "no api probes, no Worker"
  }
}

run "api_probe_without_url_is_rejected" {
  command = plan

  variables {
    probes = {
      "AUTH.03" = {
        journey_id          = "AUTH.03"
        title               = "Sign in"
        tier                = "P0"
        severity            = null
        kind                = "api"
        interval_minutes    = 5
        stale_after_minutes = 15
        url                 = null
        method              = "GET"
        expect_status       = [200]
        spec                = null
        runbook_url         = null
      }
    }
  }

  expect_failures = [var.probes]
}

run "missing_datadog_key_is_rejected" {
  command = plan

  variables {
    datadog_api_key = null
  }

  expect_failures = [cloudflare_workers_script.runner]
}
