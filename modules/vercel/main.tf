# Vercel project for a StabileStack app. In managed mode the bootstrap CLI calls
# this module with the platform team_id and a `<name>.platform.stabilestack.com`
# subdomain; in portable mode the app supplies its own team + custom domain.

resource "vercel_project" "this" {
  name           = var.name
  team_id        = var.team_id
  framework      = var.framework
  root_directory = var.root_directory
  git_repository = var.git_repository
}

resource "vercel_project_domain" "managed" {
  count = var.managed_domain == null ? 0 : 1

  team_id    = var.team_id
  project_id = vercel_project.this.id
  domain     = var.managed_domain
}

# Domains the app brings itself. Keyed by name so adding or removing one never
# reshuffles the others, which an index-keyed list would.
resource "vercel_project_domain" "extra" {
  for_each = toset(var.domains)

  team_id    = var.team_id
  project_id = vercel_project.this.id
  domain     = each.value
}

# The autopush tier's stable hostname. `git_branch` is the whole point: a domain
# without it attaches to the project and follows PRODUCTION, which would alias
# staging onto the live deployment and quietly undo the split.
resource "vercel_project_domain" "autopush" {
  count = var.autopush_domain == null ? 0 : 1

  team_id    = var.team_id
  project_id = vercel_project.this.id
  domain     = var.autopush_domain
  git_branch = var.autopush_branch
}

# Lets automation reach a protected deployment via the `x-vercel-protection-bypass`
# header. Vercel guards every preview deployment behind an SSO login, which is
# right for a human sharing a link and fatal for a probe: the autopush tier answers
# 302 to vercel.com/sso-api, so a smoke check would grade a redirect as a live site.
#
# `secret` is deliberately left computed — Vercel generates it. Supplying one would
# reintroduce the shape that took mannagame.com down (an optional input mirrored by
# an output, where the output can drift from what the resource actually holds).
#
# NOT scoped to one domain: this unlocks every protected deployment on the project,
# PR previews included. That is the grain Vercel offers.
resource "vercel_project_protection_bypass" "automation" {
  count = var.automation_bypass ? 1 : 0

  team_id    = var.team_id
  project_id = vercel_project.this.id
  is_env_var = true
  note       = "automation — post-deploy smoke"
}

locals {
  # `development` is intentionally excluded — Vercel rejects sensitive vars on the
  # development target, and dev values live in local .env.local, not Vercel.
  both_targets   = ["production", "preview"]
  prod_target    = ["production"]
  preview_target = ["preview"]

  # Per-scope env lets a var target ONE Vercel environment — the basis for the
  # production tier (STA-2): prod Clerk keys + STABILE_PROFILE=production +
  # prod DATABASE_URL go to `production` only, while the shared autopush keys go
  # to `preview` only. Vars that are identical across tiers stay in the shared
  # `environment` / `sensitive_environment` maps (both targets).
  scoped = {
    both = {
      plain     = { vars = var.environment, sensitive = false, target = local.both_targets }
      sensitive = { vars = var.sensitive_environment, sensitive = true, target = local.both_targets }
    }
    prod = {
      plain     = { vars = var.production_environment, sensitive = false, target = local.prod_target }
      sensitive = { vars = var.production_sensitive_environment, sensitive = true, target = local.prod_target }
    }
    preview = {
      plain     = { vars = var.preview_environment, sensitive = false, target = local.preview_target }
      sensitive = { vars = var.preview_sensitive_environment, sensitive = true, target = local.preview_target }
    }
  }

  all_env = flatten([
    for group in local.scoped : [
      for kind in group : [
        for k, v in kind.vars : {
          key       = k
          value     = v
          sensitive = kind.sensitive
          target    = kind.target
        }
      ]
    ]
  ])
}

# v5 plural resource: one resource holding a set of variable objects, each with
# its own `sensitive` flag. Avoids for_each over a sensitive map (the provider
# redacts `value` regardless), and `sensitive` being a required per-var field.
resource "vercel_project_environment_variables" "this" {
  count = length(local.all_env) > 0 ? 1 : 0

  team_id    = var.team_id
  project_id = vercel_project.this.id
  variables  = local.all_env
}
