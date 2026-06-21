variable "name" {
  description = "App / project name (kebab-case)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "name must be kebab-case and start with a letter."
  }
}

variable "team_id" {
  description = "Vercel team id the project belongs to (the platform team in managed mode)."
  type        = string
}

variable "framework" {
  description = "Vercel framework preset."
  type        = string
  default     = "nextjs"
}

variable "git_repository" {
  description = "Git repo to connect, e.g. { type = \"github\", repo = \"stabilestack/<name>\" }. Null to leave unconnected."
  type = object({
    type = string
    repo = string
  })
  default = null
}

variable "root_directory" {
  description = "Monorepo root directory for the app (e.g. \"apps/web\"). Null for repo root."
  type        = string
  default     = null
}

variable "managed_domain" {
  description = "Managed-mode subdomain to attach, e.g. \"<name>.platform.stabilestack.com\". Null to skip (portable mode brings its own domain)."
  type        = string
  default     = null
}

variable "environment" {
  description = "Plain (non-sensitive) environment variables, applied to all targets."
  type        = map(string)
  default     = {}
}

variable "sensitive_environment" {
  description = "Sensitive environment variables (redacted in plan/state output)."
  type        = map(string)
  default     = {}
  sensitive   = true
}
