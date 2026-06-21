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
  env_targets = ["production", "preview", "development"]

  plain_vars = [
    for k, v in var.environment : {
      key       = k
      value     = v
      sensitive = false
      target    = local.env_targets
    }
  ]

  sensitive_vars = [
    for k, v in var.sensitive_environment : {
      key       = k
      value     = v
      sensitive = true
      target    = local.env_targets
    }
  ]

  all_env = concat(local.plain_vars, local.sensitive_vars)
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
