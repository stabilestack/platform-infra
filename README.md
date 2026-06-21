# StabileStack — platform-infra

Infrastructure-as-code for the StabileStack platform. The bootstrap CLI
(`@stabile/cli`) orchestrates these modules to provision per-app vendor resources
in managed mode (~4 min), with per-project state under `~/.platform-tfstate/<name>/`.

## Status

**Phase 1: structure only.** The Terraform modules are built in **Phase 2**, in
priority order:

1. Vercel, Datadog, Sentry — the three best-supported providers, built first to
   de-risk the approach (Week 2).
2. Supabase, Stripe (test), Resend, PostHog, Inngest, GitHub — the remaining six
   (Week 3).

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
