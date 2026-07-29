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
  description = <<-EOT
    Git repo to connect, e.g. { type = "github", repo = "stabilestack/<name>" }.
    Null to leave unconnected.

    `production_branch` is what makes production a DELIBERATE act. Left null,
    Vercel treats the default branch as production, so every merge to `main`
    rebuilds and re-aliases the live domain — there is no tier between a merged
    PR and the customer. Point it at a branch nobody merges into (`production`)
    and `main` becomes a preview/autopush deploy instead; promoting is then an
    explicit push to that branch, from a commit that has already soaked.

    Only meaningful once the app has a production tier to promote INTO (a prod
    Clerk app + prod Supabase). Before that both scopes hold the same autopush
    credentials, so splitting the branches would buy a second URL and nothing
    else — see the CLI's `prodTierActive` gate.
  EOT
  type = object({
    type              = string
    repo              = string
    production_branch = optional(string)
  })
  default = null
}

variable "root_directory" {
  description = "Monorepo root directory for the app (e.g. \"apps/web\"). Null for repo root."
  type        = string
  default     = null
}

variable "domains" {
  description = <<-EOT
    Additional domains to attach, e.g. ["mannagame.com", "www.mannagame.com"].

    Separate from `managed_domain` on purpose. That one is a single nullable
    string and existing apps hold state at `vercel_project_domain.managed[0]`;
    turning it into a list would force a state move on every app already using it
    for no benefit to them. This is the escape hatch for an app that brings its
    own domain, which is every consumer product.
  EOT
  type        = list(string)
  default     = []
}

variable "managed_domain" {
  description = "Managed-mode subdomain to attach, e.g. \"<name>.platform.stabilestack.com\". Null to skip (portable mode brings its own domain)."
  type        = string
  default     = null
}

variable "autopush_domain" {
  description = <<-EOT
    Stable hostname for the autopush tier, e.g. "autopush.mannagame.com". Null to
    skip.

    Bound to `autopush_branch` rather than to the project, so it always serves
    that branch's latest PREVIEW deployment — which is where the autopush
    credentials live (preview scope = autopush Clerk app + autopush Supabase).
    Without it the tier still exists but only at Vercel's per-deployment URLs,
    which change every push: nothing to bookmark, nothing to point a smoke test
    at, and no way to ask someone to "check staging".
  EOT
  type        = string
  default     = null
}

variable "autopush_branch" {
  description = "Branch the autopush domain follows. The default branch, since that is what merges land on once production has moved to its own branch."
  type        = string
  default     = "main"
}

variable "automation_bypass" {
  description = <<-EOT
    Issue an automation bypass token for Deployment Protection.

    Needed to probe the autopush tier from CI: Vercel guards preview deployments
    behind an SSO login, so an unauthenticated request gets a 302 to
    vercel.com/sso-api and a naive smoke check reads that as a healthy site. With
    the token, automation sends `x-vercel-protection-bypass` and gets the app.

    Off by default because the token is **project-wide** — it unlocks every
    protected deployment, PR previews included, not just the autopush hostname.
    Turn it on when something is actually going to use it.
  EOT
  type        = bool
  default     = false
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
