# Example invocation (managed mode). The bootstrap CLI generates these values
# per app; this file documents the shape for manual `terraform apply` / review.

name    = "inbox-hero"
team_id = "team_xxxxxxxxxxxxxxxxxxxx"

git_repository = {
  type = "github"
  repo = "stabilestack/inbox-hero"

  # Omit until the app graduates. Once set, `main` deploys to autopush and the
  # live domain only moves on `git push origin main:production`.
  # production_branch = "production"
}

root_directory = "apps/web"
managed_domain = "inbox-hero.platform.stabilestack.com"

# The autopush tier's stable hostname, bound to `autopush_branch` (default main).
# `autopush.<app domain>`, or `<name>-autopush.platform.stabilestack.com` for an
# app with no domain of its own — flat, because *.platform.stabilestack.com is a
# single wildcard record and a wildcard matches one label.
# autopush_domain = "autopush.inboxhero.com"

# Issue a Deployment Protection bypass token so CI can probe the autopush tier
# (preview deployments 302 to a Vercel SSO login without it). Project-wide — it
# unlocks PR previews too. Read the value from the `automation_bypass_secret`
# output; never supply one.
# automation_bypass = true

environment = {
  NEXT_PUBLIC_CLERK_SIGN_IN_URL = "/sign-in"
  NEXT_PUBLIC_CLERK_SIGN_UP_URL = "/sign-up"
}

# Pass sensitive values via -var or a gitignored *.auto.tfvars, never committed:
# sensitive_environment = {
#   STRIPE_SECRET_KEY = "sk_test_…"   # identical across tiers → both targets
# }

# Production tier (STA-2): per-scope maps target ONE Vercel environment. The CLI
# emits these from the tier-keyed inputs — prod credentials to `production`, the
# shared autopush credentials to `preview`.
# production_environment = {
#   STABILE_PROFILE               = "production"
#   NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = "pk_live_…prod app…"
# }
# production_sensitive_environment = {
#   CLERK_SECRET_KEY = "sk_live_…prod app…"
#   DATABASE_URL     = "postgres://…prod supabase…"
# }
# preview_environment = {
#   STABILE_PROFILE               = "autopush"
#   NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY = "pk_live_…autopush app…"
# }
# preview_sensitive_environment = {
#   CLERK_SECRET_KEY = "sk_live_…autopush app…"
# }
