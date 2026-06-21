# Registers the app as a Datadog service and (optionally) a baseline error-rate
# monitor. The bootstrap CLI runs this with DD_API_KEY / DD_APP_KEY in the env;
# DD site/region is whatever the platform Datadog account uses (set DD_HOST /
# api_url at the provider level when wiring apply — confirm the region, the
# default US1 endpoint differs from US5).

locals {
  monitor_query = "logs(\"service:${var.service} status:error\").index(\"*\").rollup(\"count\").last(\"5m\") > ${var.monitor_critical}"
}

resource "datadog_service_definition_yaml" "this" {
  service_definition = yamlencode(merge(
    {
      "schema-version" = "v2.2"
      "dd-service"     = var.service
      tags             = ["managed-by:stabilestack"]
    },
    var.team == "" ? {} : { team = var.team },
    var.tier == "" ? {} : { tier = var.tier },
  ))
}

resource "datadog_monitor" "errors" {
  count = var.monitor_enabled ? 1 : 0

  name    = "${var.service} — error rate"
  type    = "log alert"
  query   = local.monitor_query
  message = trimspace("Error rate elevated for ${var.service}. ${join(" ", var.notify)}")

  monitor_thresholds {
    critical = var.monitor_critical
  }

  tags = ["service:${var.service}", "env:${var.env}", "managed-by:stabilestack"]
}
