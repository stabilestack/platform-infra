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
