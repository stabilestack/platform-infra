# Creates a PostHog project for the app. Provider reads its API key + host from
# the environment (set by the CLI from managed secrets).

resource "posthog_project" "this" {
  name = var.name
}
