# External journey probes: a Cloudflare Worker on a 5-minute cron runs the
# `api` probes from outside the app's hosting and pushes results to Datadog.
# `browser` probes run elsewhere (a scheduled Playwright job) and push the same
# metrics; this module only monitors them. Every probe gets a staleness
# monitor, and by default a failure monitor.

locals {
  worker_name = coalesce(var.worker_name, "${var.service}-journey-probes")
  api_probes  = { for id, p in var.probes : id => p if p.kind == "api" }

  base_tags = concat(
    ["service:${var.service}", "env:${var.env}", "managed-by:stabilestack", "source:journey-contract"],
    var.tags,
  )

  probes = {
    for id, p in var.probes : id => merge(p, {
      filter = "journey:${lower(id)},service:${var.service},env:${var.env}"
      tags = concat(
        local.base_tags,
        ["journey:${lower(id)}", "tier:${lower(p.tier)}", "probe_kind:${p.kind}"],
        p.severity == null ? [] : ["severity:${lower(p.severity)}"],
      )
      runbook = p.runbook_url == null ? null : "Runbook: ${p.runbook_url}"
    })
  }

  severity_priority = { S1 = 1, S2 = 2, S3 = 3, S4 = 4 }
}

resource "cloudflare_workers_script" "runner" {
  count = length(local.api_probes) > 0 ? 1 : 0

  account_id         = var.cloudflare_account_id
  script_name        = local.worker_name
  content            = file("${path.module}/worker/probe-runner.mjs")
  main_module        = "probe-runner.mjs"
  compatibility_date = var.compatibility_date

  bindings = [
    {
      name = "PROBES"
      type = "json"
      json = jsonencode({
        for id, p in local.api_probes : id => {
          url              = p.url
          method           = p.method
          expect_status    = p.expect_status
          interval_minutes = p.interval_minutes
        }
      })
    },
    { name = "PROBE_HEADERS", type = "secret_text", text = jsonencode(var.probe_request_headers) },
    { name = "DD_API_KEY", type = "secret_text", text = var.datadog_api_key },
    { name = "DD_SITE", type = "plain_text", text = var.datadog_site },
    { name = "METRIC_PREFIX", type = "plain_text", text = var.metric_prefix },
    { name = "SERVICE", type = "plain_text", text = var.service },
    { name = "ENV", type = "plain_text", text = var.env },
    { name = "TIMEOUT_MS", type = "plain_text", text = tostring(var.timeout_ms) },
  ]

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = var.datadog_api_key != null
      error_message = "datadog_api_key is required when there are api probes to run."
    }
  }
}

resource "cloudflare_workers_cron_trigger" "runner" {
  count = length(local.api_probes) > 0 ? 1 : 0

  account_id  = var.cloudflare_account_id
  script_name = cloudflare_workers_script.runner[0].script_name
  schedules   = [{ cron = "*/5 * * * *" }]

  lifecycle {
    prevent_destroy = true
  }
}

# Fires when a probe has reported nothing for stale_after_minutes. The
# threshold can never trip; only missing data alerts. A silent probe is a
# monitoring fault, not a user-facing outage, so it always tickets.
resource "datadog_monitor" "stale" {
  for_each = local.probes

  name  = "[TICKET] ${each.value.title} (${each.key}): ${each.value.kind} probe stopped reporting"
  type  = "metric alert"
  query = "max(last_5m):max:${var.metric_prefix}.success{${each.value.filter}} < 0"

  message = join("\n\n", compact([
    "The ${each.value.kind} probe for ${each.value.title} (${each.key}) has not reported for ${each.value.stale_after_minutes} minutes. Until it does, this journey has no external probe coverage.",
    each.value.kind == "api" ? "Runner: Cloudflare Worker ${local.worker_name}." : "Runner: the scheduled browser-probe job (spec ${coalesce(each.value.spec, "unknown")}).",
    each.value.runbook,
    join(" ", var.ticket_notify),
  ]))

  monitor_thresholds {
    critical = 0
  }

  notify_no_data    = true
  no_data_timeframe = each.value.stale_after_minutes

  priority = "4"
  tags     = concat(each.value.tags, ["alert-action:ticket", "probe-alert:stale"])
  validate = var.validate_queries

  lifecycle {
    prevent_destroy = true
  }
}

# Fires when every run in the stale_after window failed (3 consecutive runs
# for a 5-minute API probe). P0 pages; everything else tickets.
resource "datadog_monitor" "failing" {
  for_each = var.failure_alerts ? local.probes : {}

  name  = "[${each.value.tier == "P0" ? "PAGE" : "TICKET"}] ${each.value.title} (${each.key}): ${each.value.kind} probe failing"
  type  = "metric alert"
  query = "max(last_${each.value.stale_after_minutes}m):max:${var.metric_prefix}.success{${each.value.filter}} < 1"

  message = join("\n\n", compact([
    "Every ${each.value.kind} probe run for ${each.value.title} (${each.key}) in the last ${each.value.stale_after_minutes} minutes failed.",
    each.value.runbook,
    join(" ", each.value.tier == "P0" ? var.page_notify : var.ticket_notify),
  ]))

  monitor_thresholds {
    critical = 1
  }

  priority = tostring(lookup(local.severity_priority, coalesce(each.value.severity, "none"), each.value.tier == "P0" ? 2 : 4))
  tags     = concat(each.value.tags, ["alert-action:${each.value.tier == "P0" ? "page" : "ticket"}", "probe-alert:failing"])
  validate = var.validate_queries

  lifecycle {
    prevent_destroy = true
  }
}
