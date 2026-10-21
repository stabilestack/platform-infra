variable "organization" {
  description = "Sentry organization slug."
  type        = string
}

variable "project" {
  description = "Sentry project slug the rules belong to."
  type        = string
}

# Each rule's conditions, filters and actions are lists of single-key objects,
# one per entry, mirroring the provider's *_v2 attributes. Only the commonly
# used kinds are typed here; add a kind by adding an optional attribute.
variable "rules" {
  description = "Issue-alert rules keyed by a stable slug (the slug is the resource address, so renaming the rule's title is an in-place update)."
  type = map(object({
    title             = string
    severity          = optional(string)
    environment       = optional(string)
    frequency_minutes = optional(number, 30)
    action_match      = optional(string, "any")
    filter_match      = optional(string, "all")
    owner             = optional(string)

    conditions = list(object({
      event_frequency = optional(object({
        value               = number
        interval            = string
        comparison_type     = optional(string, "count")
        comparison_interval = optional(string)
      }))
      event_unique_user_frequency = optional(object({
        value               = number
        interval            = string
        comparison_type     = optional(string, "count")
        comparison_interval = optional(string)
      }))
      first_seen_event             = optional(object({}))
      regression_event             = optional(object({}))
      reappeared_event             = optional(object({}))
      new_high_priority_issue      = optional(object({}))
      existing_high_priority_issue = optional(object({}))
    }))

    filters = optional(list(object({
      tagged_event      = optional(object({ key = string, match = string, value = optional(string) }))
      event_attribute   = optional(object({ attribute = string, match = string, value = optional(string) }))
      level             = optional(object({ level = string, match = string }))
      issue_occurrences = optional(object({ value = number }))
      age_comparison    = optional(object({ comparison_type = string, time = string, value = number }))
    })), [])

    actions = list(object({
      notify_email = optional(object({
        target_type       = string
        target_identifier = optional(string)
        fallthrough_type  = optional(string)
      }))
      slack_notify_service = optional(object({
        workspace = string
        channel   = string
        tags      = optional(set(string))
        notes     = optional(string)
      }))
      pagerduty_notify_service = optional(object({ account = string, service = string, severity = string }))
      notify_event_service     = optional(object({ service = string }))
    }))
  }))
  default = {}

  validation {
    condition     = alltrue([for k, _ in var.rules : can(regex("^[a-z][a-z0-9-]*$", k))])
    error_message = "Rule keys must be kebab-case slugs."
  }

  validation {
    condition     = alltrue([for r in var.rules : r.severity == null || contains(["S1", "S2", "S3", "S4"], coalesce(r.severity, "none"))])
    error_message = "severity must be S1, S2, S3 or S4."
  }

  validation {
    condition     = alltrue([for r in var.rules : length(r.conditions) > 0 && length(r.actions) > 0])
    error_message = "Every rule needs at least one condition and one action."
  }

  # Each list entry must say exactly one thing; a two-key entry would
  # silently become two conditions or actions in the provider.
  validation {
    condition = alltrue(flatten([for r in var.rules : [
      for e in concat(r.conditions, r.filters, r.actions) : length([for v in values(e) : v if v != null]) == 1
    ]]))
    error_message = "Each condition, filter and action entry must set exactly one kind."
  }
}
