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

resource "vercel_project_environment_variable" "plain" {
  for_each = var.environment

  team_id    = var.team_id
  project_id = vercel_project.this.id
  key        = each.key
  value      = each.value
  target     = ["production", "preview", "development"]
}

resource "vercel_project_environment_variable" "sensitive" {
  for_each = var.sensitive_environment

  team_id    = var.team_id
  project_id = vercel_project.this.id
  key        = each.key
  value      = each.value
  sensitive  = true
  target     = ["production", "preview", "development"]
}
