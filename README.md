# StabileStack — platform-infra

Infrastructure-as-code for the StabileStack platform. The bootstrap CLI
(`@stabile/cli`) orchestrates these modules to provision per-app vendor resources
in managed mode (~4 min), with per-project state under `~/.platform-tfstate/<name>/`.

## Status

**Phase 2 in progress.** Module build order:

1. **Vercel** ✓, **Datadog** ✓, **Sentry** ✓ — the three de-risk modules, all
   `tofu validate` + `tofu fmt` clean (OpenTofu 1.12.3). `plan`/`apply` not yet
   exercised (needs vendor tokens). See each module's README for provider pin +
   validation status.
2. Supabase, Stripe (test), Resend, PostHog, Inngest, GitHub — the remaining six
   (Week 3).

The `@stabile/cli` provision step is terraform-aware: it detects a
terraform/opentofu binary and the presence of a vendor's module, and reports
readiness per vendor. Actual `plan`/`apply` execution lands behind a `--apply`
flag once vendor tokens exist.

**Clerk is intentionally not a Terraform module** — it has no public Management API
for app creation. The managed-auth pattern reuses shared per-env Clerk apps whose
keys live in `~/.platform-secrets/managed/clerk.env`; the CLI wires them into each
new app's `.env.local` directly.

## Planned layout

```
modules/
  vercel/        Vercel project + domain + env scopes
  datadog/       service, monitors, dashboards (IaC apply per SAL-548 pattern)
  sentry/        project + alert rules
  supabase/      project + pooler config
  stripe/        test-mode products/prices
  resend/        domain + DNS
  posthog/       project
  inngest/       workspace
  github/        app repo creation
environments/
  managed/       shared managed-mode wiring
```

## Conventions (when modules land)

- Idempotent upserts, never destructive recreates (matches the IaC-apply rule).
- Vendor IDs are external references; stable internal UUIDs are the source of truth
  (designed-for-swap, so managed → portable graduation doesn't bake in vendor specifics).
- State is per-project and never committed.
