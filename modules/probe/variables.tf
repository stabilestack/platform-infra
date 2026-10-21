# `journeys_contract_version` and `probes` are top-level keys of the
# `journeys.auto.tfvars.json` that `@stabile/journeys` emits; pass them through
# unchanged (contract v1).

variable "journeys_contract_version" {
  description = "Version of the journeys tfvars contract. This module understands v1 only."
  type        = number

  validation {
    condition     = var.journeys_contract_version == 1
    error_message = "This module consumes journeys tfvars contract v1. Upgrade the module before consuming a newer contract."
  }
}

variable "probes" {
  description = "Probe entries keyed by journey id, exactly as emitted by @stabile/journeys."
  type = map(object({
    journey_id          = string
    title               = string
    tier                = string
    severity            = string
    kind                = string
    interval_minutes    = number
    stale_after_minutes = number
    url                 = string
    method              = string
    expect_status       = list(number)
    spec                = string
    runbook_url         = string
  }))

  validation {
    condition     = alltrue([for k, p in var.probes : k == p.journey_id])
    error_message = "Each probes key must equal its journey_id; the key is the resource address."
  }

  validation {
    condition     = alltrue([for p in var.probes : contains(["api", "browser"], p.kind)])
    error_message = "probe kind must be api or browser."
  }

  validation {
    condition = alltrue([for p in var.probes :
      p.kind != "api" || (p.url != null && p.method != null && p.expect_status != null)
    ])
    error_message = "api probes need url, method and expect_status."
  }

  # The runner ticks every 5 minutes and runs a probe on ticks that divide its interval.
  validation {
    condition     = alltrue([for p in var.probes : p.kind != "api" || p.interval_minutes % 5 == 0])
    error_message = "api probe interval_minutes must be a multiple of 5 (the runner's cron cadence)."
  }

  # Datadog needs no_data_timeframe >= 2x the 5-minute evaluation window.
  validation {
    condition     = alltrue([for p in var.probes : p.stale_after_minutes >= 10])
    error_message = "stale_after_minutes must be at least 10."
  }
}

variable "service" {
  description = "Datadog service the journeys belong to; tags every metric and monitor."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.service))
    error_message = "service must be kebab-case and start with a letter."
  }
}

variable "env" {
  description = "Environment tag on every metric and monitor."
  type        = string
  default     = "production"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account that hosts the probe runner Worker."
  type        = string
}

variable "worker_name" {
  description = "Worker script name. Null derives \"<service>-journey-probes\"."
  type        = string
  default     = null
}

variable "compatibility_date" {
  description = "Workers runtime compatibility date for the runner."
  type        = string
  default     = "2026-10-01"
}

variable "datadog_site" {
  description = "Datadog site the runner submits metrics to (datadoghq.com, us5.datadoghq.com, datadoghq.eu, ...)."
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_api_key" {
  description = "Datadog API key the runner submits metrics with. Use a dedicated key: an API key can only submit data, and the runner must never hold an app key."
  type        = string
  sensitive   = true
  default     = null
}

variable "probe_request_headers" {
  description = "Request headers per journey id, e.g. the probe user's bearer token. The runner holds these and nothing else of the app's."
  type        = map(map(string))
  sensitive   = true
  default     = {}
}

variable "timeout_ms" {
  description = "Per-request timeout for a probe."
  type        = number
  default     = 10000
}

variable "metric_prefix" {
  description = "Prefix of the metrics the runners submit (<prefix>.success, <prefix>.duration_ms)."
  type        = string
  default     = "journey.probe"
}

variable "failure_alerts" {
  description = "Create a failure monitor per probe (fires when every run in the stale_after window failed), alongside the staleness monitor."
  type        = bool
  default     = true
}

variable "page_notify" {
  description = "Notification handles for P0 probe failures."
  type        = list(string)
  default     = []
}

variable "ticket_notify" {
  description = "Notification handles for staleness and for P1-P3 probe failures."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags on every monitor."
  type        = list(string)
  default     = []
}

variable "validate_queries" {
  description = "Ask Datadog to validate monitor queries during plan. Needs real API keys; turn off only for offline tests."
  type        = bool
  default     = true
}
