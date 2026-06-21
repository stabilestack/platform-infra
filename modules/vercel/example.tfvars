# Example invocation (managed mode). The bootstrap CLI generates these values
# per app; this file documents the shape for manual `terraform apply` / review.

name    = "inbox-hero"
team_id = "team_xxxxxxxxxxxxxxxxxxxx"

git_repository = {
  type = "github"
  repo = "stabilestack/inbox-hero"
}

root_directory = "apps/web"
managed_domain = "inbox-hero.platform.stabilestack.com"

environment = {
  NEXT_PUBLIC_CLERK_SIGN_IN_URL = "/sign-in"
  NEXT_PUBLIC_CLERK_SIGN_UP_URL = "/sign-up"
}

# Pass sensitive values via -var or a gitignored *.auto.tfvars, never committed:
# sensitive_environment = {
#   CLERK_SECRET_KEY = "sk_live_…"
#   STRIPE_SECRET_KEY = "sk_test_…"
# }
