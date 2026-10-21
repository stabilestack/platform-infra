# One Datadog SLO per journey contract, plus one burn-rate monitor per burn
# alert the contract derives (P0: page + ticket, P1: ticket, P2/P3: none).
# Everything here is generated: change the journey contract and re-emit, never
# edit these in the Datadog UI (the nightly drift plan reports UI edits).

locals {
  # Datadog SLOs only offer these rolling windows.
  supported_timeframes = { "7" = "7d", "30" = "30d", "90" = "90d" }

  base_tags = concat(
    ["service:${var.service}", "env:${var.env}", "managed-by:stabilestack", "source:journey-contract"],
    var.tags,
  )

  slos = {
    for id, s in var.slos : id => merge(s, {
      # Unsupported windows map only through window_remaps (28 -> 30d by
      # default); anything else is null and fails the precondition below.
      timeframe = lookup(merge(var.window_remaps, local.supported_timeframes), tostring(s.window_days), null)
      remapped  = !contains(keys(local.supported_timeframes), tostring(s.window_days))

      # Datadog lowercases tag values; do it here so plans stay clean.
      tags = concat(
        local.base_tags,
        ["journey:${lower(id)}", "tier:${lower(s.tier)}"],
        s.severity == null ? [] : ["severity:${lower(s.severity)}"],
        s.owner == null ? [] : ["owner:${lower(s.owner)}"],
      )

      # Contract tags win over query_tags. `{*}` when there is no filter at all.
      good_filter  = s.sli.good == null ? null : join(",", [for k, v in merge(var.query_tags, s.sli.good.tags) : "${k}:${v}"])
      total_filter = join(",", [for k, v in merge(var.query_tags, s.sli.total.tags) : "${k}:${v}"])
      lag_filter   = s.sli.lag == null ? null : join(",", [for k, v in merge(var.query_tags, s.sli.lag.tags) : "${k}:${v}"])
    })
  }

  # Ratio: good / total counters. Freshness: `lag` is a distribution in
  # seconds, so good = samples at or under the threshold (a Datadog threshold
  # query; the metric needs percentiles/advanced queries enabled), and total =
  # triggers, so work that never finishes still burns budget.
  queries = {
    for id, s in local.slos : id => {
      numerator = s.sli.kind == "ratio" ? (
        "sum:${s.sli.good.metric}{${coalesce(s.good_filter, "*")}}.as_count()"
        ) : (
        "count(v: v<=${s.sli.within_seconds}):${s.sli.lag.metric}{${coalesce(s.lag_filter, "*")}}.as_count()"
      )
      denominator = "sum:${s.sli.total.metric}{${coalesce(s.total_filter, "*")}}.as_count()"
    }
  }

  # Keyed "<journey id>/<action>", so a journey's page and ticket monitors
  # have stable, readable addresses.
  burn_alerts = merge([
    for id, s in local.slos : {
      for a in s.burn_alerts : "${id}/${a.action}" => merge(a, {
        journey_id = id
        long       = a.long_window_minutes % 60 == 0 ? "${a.long_window_minutes / 60}h" : "${a.long_window_minutes}m"
        short      = a.short_window_minutes % 60 == 0 ? "${a.short_window_minutes / 60}h" : "${a.short_window_minutes}m"
      })
    }
  ]...)

  severity_priority = { S1 = 1, S2 = 2, S3 = 3, S4 = 4 }
}

resource "datadog_service_level_objective" "this" {
  for_each = local.slos

  name = "${each.value.title} (${each.key})"
  type = "metric"
  description = join("\n\n", compact([
    each.value.description,
    each.value.runbook_url == null ? null : "Runbook: ${each.value.runbook_url}",
    "Generated from the ${each.key} journey contract. Change the contract, not this SLO.",
  ]))

  query {
    numerator   = local.queries[each.key].numerator
    denominator = local.queries[each.key].denominator
  }

  thresholds {
    timeframe = each.value.timeframe
    target    = each.value.target
  }

  tags     = each.value.tags
  validate = var.validate_queries

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = each.value.timeframe != null
      error_message = "${each.key}: window_days ${each.value.window_days} is not a Datadog SLO timeframe (7, 30 or 90 days) and has no entry in window_remaps."
    }
  }
}

resource "datadog_monitor" "burn_rate" {
  for_each = local.burn_alerts

  name = "[${upper(each.value.action)}] ${local.slos[each.value.journey_id].title} (${each.value.journey_id}): error budget burning ${each.value.burn_rate}x"
  type = "slo alert"
  query = format(
    "burn_rate(\"%s\").over(\"%s\").long_window(\"%s\").short_window(\"%s\") > %s",
    datadog_service_level_objective.this[each.value.journey_id].id,
    local.slos[each.value.journey_id].timeframe,
    each.value.long,
    each.value.short,
    each.value.burn_rate,
  )

  message = join("\n\n", compact([
    "${local.slos[each.value.journey_id].title} (${each.value.journey_id}, ${local.slos[each.value.journey_id].tier}) is burning its error budget at ${each.value.burn_rate}x over ${each.value.long}, confirmed over ${each.value.short}.",
    local.slos[each.value.journey_id].runbook_url == null ? null : "Runbook: ${local.slos[each.value.journey_id].runbook_url}",
    local.slos[each.value.journey_id].owner == null ? null : "Owner: ${local.slos[each.value.journey_id].owner}",
    join(" ", each.value.action == "page" ? var.page_notify : var.ticket_notify),
  ]))

  monitor_thresholds {
    critical = each.value.burn_rate
  }

  priority = tostring(lookup(
    local.severity_priority,
    coalesce(local.slos[each.value.journey_id].severity, "none"),
    each.value.action == "page" ? 2 : 4,
  ))

  tags     = concat(local.slos[each.value.journey_id].tags, ["alert-action:${each.value.action}"])
  validate = var.validate_queries

  lifecycle {
    prevent_destroy = true
  }
}
