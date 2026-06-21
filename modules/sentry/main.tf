# Creates a Sentry project for the app and exposes its DSN. The bootstrap CLI
# runs this with SENTRY_AUTH_TOKEN in the env.

resource "sentry_project" "this" {
  organization = var.organization
  teams        = [var.team]
  name         = var.name
  slug         = var.slug
  platform     = var.platform
}

# Default project key — the DSN the app uses to report events.
data "sentry_key" "default" {
  organization = var.organization
  project      = sentry_project.this.slug
  name         = "Default"
}
