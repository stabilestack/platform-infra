variable "service" {
  description = "Datadog service name for the app (matches the app's DD_SERVICE)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.service))
    error_message = "service must be kebab-case and start with a letter."
  }
}

variable "team" {
  description = "Owning Datadog team handle (for the service definition)."
  type        = string
  default     = ""
}

variable "env" {
  description = "Environment tag applied to the monitor."
  type        = string
  default     = "production"
}

variable "tier" {
  description = "Service tier label in the service definition (e.g. \"frontend\")."
  type        = string
  default     = ""
}

variable "notify" {
  description = "Notification targets appended to the monitor message (e.g. [\"@slack-alerts\"])."
  type        = list(string)
  default     = []
}

variable "monitor_enabled" {
  description = "Create the baseline log error-rate monitor."
  type        = bool
  default     = true
}

variable "monitor_critical" {
  description = "Error-log count over 5m that trips the monitor."
  type        = number
  default     = 10
}
