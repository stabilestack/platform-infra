# `journeys_contract_version` and `slos` are the top-level keys of the
# `journeys.auto.tfvars.json` that `@stabile/journeys` emits; pass them through
# unchanged. Their shape is the v1 contract
# (`@stabile/journeys/schema/journeys-tfvars.v1.schema.json`). Keys the
# emitter adds later without a version bump are dropped by the type below, so
# an additive change never breaks a plan.

variable "journeys_contract_version" {
  description = "Version of the journeys tfvars contract. This module understands v1 only."
  type        = number

  validation {
    condition     = var.journeys_contract_version == 1
    error_message = "This module consumes journeys tfvars contract v1. Upgrade the module before consuming a newer contract."
  }
}

variable "slos" {
  description = "SLO entries keyed by journey id, exactly as emitted by @stabile/journeys."
  type = map(object({
    journey_id  = string
    title       = string
    description = string
    tier        = string
    severity    = string
    owner       = string
    sli = object({
      kind           = string
      good           = object({ metric = string, tags = map(string) })
      total          = object({ metric = string, tags = map(string) })
      lag            = object({ metric = string, tags = map(string) })
      within_seconds = number
    })
    target      = number
    window_days = number
    burn_alerts = list(object({
      action               = string
      burn_rate            = number
      long_window_minutes  = number
      short_window_minutes = number
    }))
    runbook_path = string
    runbook_url  = string
  }))

  validation {
    condition     = alltrue([for k, s in var.slos : k == s.journey_id])
    error_message = "Each slos key must equal its journey_id; the key is the resource address."
  }

  validation {
    condition = alltrue([for s in var.slos : (
      s.sli.kind == "ratio" ? s.sli.good != null :
      s.sli.kind == "freshness" ? (s.sli.lag != null && s.sli.within_seconds != null) : false
    )])
    error_message = "sli.kind must be ratio (with good) or freshness (with lag and within_seconds)."
  }

  # Defence in depth: the emitter already derives burn alerts from the tier,
  # but a hand-edited tfvars must not be able to page for a P1-P3 journey.
  validation {
    condition = alltrue(flatten([for s in var.slos : [
      for a in s.burn_alerts : a.action == "ticket" || (a.action == "page" && s.tier == "P0")
    ]]))
    error_message = "Only P0 journeys may have page burn alerts; P1 and lower get ticket alerts only."
  }

  validation {
    condition = alltrue([for s in var.slos :
      length(s.burn_alerts) == length(distinct([for a in s.burn_alerts : a.action]))
    ])
    error_message = "At most one burn alert per action (page, ticket) per journey; the action is part of the monitor address."
  }

  validation {
    condition = alltrue(flatten([for s in var.slos : [
      for a in s.burn_alerts : a.short_window_minutes < a.long_window_minutes && a.long_window_minutes <= 2880
    ]]))
    error_message = "Burn alert windows must have short < long and long <= 48h (Datadog's burn-rate limit)."
  }
}

variable "service" {
  description = "Datadog service the journeys belong to; tags every SLO and monitor."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.service))
    error_message = "service must be kebab-case and start with a letter."
  }
}

variable "env" {
  description = "Environment tag on every SLO and monitor."
  type        = string
  default     = "production"
}

variable "query_tags" {
  description = "Tag filters added to every SLI metric query, e.g. { env = \"production\", service = \"my-app\" }. Contract tags win on conflict."
  type        = map(string)
  default     = {}
}

variable "window_remaps" {
  description = "Datadog timeframe for each window_days Datadog SLOs don't support (only 7, 30 and 90 days exist), keyed by days. The contracts default to 28 days, mapped to 30d. Any other unsupported window fails the plan rather than being guessed."
  type        = map(string)
  default     = { "28" = "30d" }

  validation {
    condition     = alltrue([for t in values(var.window_remaps) : contains(["7d", "30d", "90d"], t)])
    error_message = "window_remaps values must be 7d, 30d or 90d."
  }
}

variable "page_notify" {
  description = "Notification handles for page burn alerts, e.g. [\"@slack-ops-alerts-critical\"]."
  type        = list(string)
  default     = []
}

variable "ticket_notify" {
  description = "Notification handles for ticket burn alerts, e.g. [\"@slack-ops-alerts\"]."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Extra tags on every SLO and monitor."
  type        = list(string)
  default     = []
}

variable "validate_queries" {
  description = "Ask Datadog to validate SLO and monitor queries during plan. Needs real API keys; turn off only for offline tests."
  type        = bool
  default     = true
}
