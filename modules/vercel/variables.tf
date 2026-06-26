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
  description = "Plain (non-sensitive) environment variables, applied to BOTH targets (production + preview)."
  type        = map(string)
  default     = {}
}

variable "sensitive_environment" {
  description = "Sensitive environment variables applied to BOTH targets (redacted in plan/state output)."
  type        = map(string)
  default     = {}
  sensitive   = true
}

# Per-scope env (STA-2 production tier). A var set here targets ONE Vercel
# environment, letting the production deployment use prod credentials (Clerk
# prod app, prod Supabase) while preview/autopush deployments use the shared
# autopush credentials.
variable "production_environment" {
  description = "Plain env vars applied to the `production` target only."
  type        = map(string)
  default     = {}
}

variable "production_sensitive_environment" {
  description = "Sensitive env vars applied to the `production` target only (redacted)."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "preview_environment" {
  description = "Plain env vars applied to the `preview` target only."
  type        = map(string)
  default     = {}
}

variable "preview_sensitive_environment" {
  description = "Sensitive env vars applied to the `preview` target only (redacted)."
  type        = map(string)
  default     = {}
  sensitive   = true
}
