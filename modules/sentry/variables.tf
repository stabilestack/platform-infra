variable "organization" {
  description = "Sentry organization slug."
  type        = string
}

variable "team" {
  description = "Sentry team slug that will own the project."
  type        = string
}

variable "name" {
  description = "Project name (also used as the slug if `slug` is null)."
  type        = string
}

variable "slug" {
  description = "Project slug. Null derives it from `name`."
  type        = string
  default     = null
}

variable "platform" {
  description = "Sentry platform identifier."
  type        = string
  default     = "javascript-nextjs"
}
