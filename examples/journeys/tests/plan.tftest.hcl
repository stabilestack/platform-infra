# Acceptance: the tfvars emitted by @stabile/journeys (journeys.auto.tfvars.json,
# generated from sample/journeys.mjs) plans cleanly against the slo and probe
# modules. Mocked providers: no credentials, no API calls, nothing created.

mock_provider "datadog" {}
mock_provider "cloudflare" {}

variables {
  validate_queries      = false
  probe_datadog_api_key = "test-key"
}

run "emitted_tfvars_plan_cleanly" {
  command = plan

  assert {
    condition     = length(module.slo.timeframes) == 8
    error_message = "one SLO per emitted entry"
  }

  assert {
    condition = (
      module.slo.timeframes["AUTH.03"].timeframe == "30d" &&
      module.slo.timeframes["REPORTS.01"].timeframe == "90d" &&
      module.slo.timeframes["SEARCH.01"].timeframe == "7d"
    )
    error_message = "window mapping"
  }

  # 5 P0 x (page + ticket) + 2 P1 x ticket + P2 none = 12.
  assert {
    condition     = length(module.slo.burn_rate_monitor_ids) == 12
    error_message = "burn monitor count: ${length(module.slo.burn_rate_monitor_ids)}"
  }

  assert {
    condition     = length([for k in keys(module.slo.burn_rate_monitor_ids) : k if endswith(k, "/page") && contains(["NOTES.02", "REPORTS.01", "SEARCH.01"], split("/", k)[0])]) == 0
    error_message = "P1 and lower never page"
  }

  assert {
    condition     = length(module.probe.stale_monitor_ids) == 3 && module.probe.worker_name == "example-app-journey-probes"
    error_message = "3 probes (2 api, 1 browser) and one runner"
  }
}
