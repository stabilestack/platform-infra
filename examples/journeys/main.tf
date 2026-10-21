# How an app wires its journey contracts to monitoring. The app commits
# `journeys.auto.tfvars.json` (emitted by `@stabile/journeys`) next to this
# file; Terraform loads it automatically, and its three top-level keys pass
# straight through to the modules. Copy this into the app's monitoring
# directory and point `source` at a pinned ref:
#   source = "github.com/stabilestack/platform-infra//modules/slo?ref=<tag>"

# DD_API_KEY / DD_APP_KEY from the environment. Plan runs with a read-only app
# key; only the apply job holds a write-capable one.
provider "datadog" {
  api_url = var.datadog_api_url
}

# CLOUDFLARE_API_TOKEN from the environment (Workers Scripts: Edit, apply only).
provider "cloudflare" {}

variable "journeys_contract_version" {
  description = "From journeys.auto.tfvars.json."
  type        = number
}

variable "slos" {
  description = "From journeys.auto.tfvars.json; typed and validated by modules/slo."
  type        = any
}

variable "probes" {
  description = "From journeys.auto.tfvars.json; typed and validated by modules/probe."
  type        = any
}

variable "service" {
  description = "The app's Datadog service name."
  type        = string
  default     = "example-app"
}

variable "datadog_api_url" {
  description = "Datadog API base URL for the account's site."
  type        = string
  default     = "https://api.datadoghq.com/"
}

variable "cloudflare_account_id" {
  description = "Cloudflare account hosting the probe runner."
  type        = string
  default     = "0123456789abcdef0123456789abcdef"
}

variable "probe_datadog_api_key" {
  description = "Submission-only Datadog API key for the probe runner (TF_VAR_probe_datadog_api_key)."
  type        = string
  sensitive   = true
  default     = null
}

variable "probe_request_headers" {
  description = "Probe user credentials per journey id (TF_VAR_probe_request_headers)."
  type        = map(map(string))
  sensitive   = true
  default     = {}
}

variable "validate_queries" {
  description = "Validate Datadog queries against the API during plan."
  type        = bool
  default     = true
}

locals {
  page_notify   = ["@slack-ops-alerts-critical"]
  ticket_notify = ["@slack-ops-alerts"]
}

module "slo" {
  source = "../../modules/slo"

  journeys_contract_version = var.journeys_contract_version
  slos                      = var.slos

  service          = var.service
  query_tags       = { env = "production" }
  page_notify      = local.page_notify
  ticket_notify    = local.ticket_notify
  validate_queries = var.validate_queries
}

module "probe" {
  source = "../../modules/probe"

  journeys_contract_version = var.journeys_contract_version
  probes                    = var.probes

  service               = var.service
  cloudflare_account_id = var.cloudflare_account_id
  datadog_api_key       = var.probe_datadog_api_key
  probe_request_headers = var.probe_request_headers
  page_notify           = local.page_notify
  ticket_notify         = local.ticket_notify
  validate_queries      = var.validate_queries
}

output "slo_ids" {
  value = module.slo.slo_ids
}

output "timeframes" {
  value = module.slo.timeframes
}
