# StabileStack — platform-infra

Infrastructure-as-code for the StabileStack platform. The bootstrap CLI
(`@stabile/cli`) orchestrates these modules to provision per-app vendor resources
in managed mode (~4 min), with per-project state under `~/.platform-tfstate/<name>/`.

## Status

**Phase 2 in progress.** Module build order:

Six vendors have Terraform modules (all `tofu validate` + `tofu fmt` clean,
OpenTofu 1.12.3); three provision via API instead (see
[`docs/api-provisioning.md`](docs/api-provisioning.md)). Three more modules
compile journey reliability contracts into monitoring, with plan-on-PR and
apply-on-merge: see [`docs/journey-monitoring.md`](docs/journey-monitoring.md).

| Vendor | Module | Provider |
|---|---|---|
| Vercel | `modules/vercel` | `vercel/vercel ~> 5.0` |
| Datadog | `modules/datadog` | `DataDog/datadog ~> 4.0` |
| Sentry | `modules/sentry` | `jianyuan/sentry ~> 0.15` |
| GitHub | `modules/github` | `integrations/github ~> 6.0` |
| Supabase | `modules/supabase` | `supabase/supabase ~> 1.0` |
| PostHog | `modules/posthog` | `PostHog/posthog ~> 1.0` |
| Journey SLOs + burn-rate alerts | `modules/slo` | `DataDog/datadog ~> 4.0` |
| Journey probes (Workers cron runner + monitors) | `modules/probe` | `DataDog/datadog ~> 4.0`, `cloudflare/cloudflare ~> 5.0` |
| Sentry issue-alert rules | `modules/sentry-alert` | `jianyuan/sentry ~> 0.15` |
| Stripe | — (API) | unmaintained TF providers; use the Stripe API |
| Resend | — (API) | no real TF provider |
| Inngest | — (API) | no TF provider |

`plan`/`apply` is not yet exercised against any provider (needs vendor tokens).
See each module's README for its validation status.

The `@stabile/cli` provision step is terraform-aware: it detects a
terraform/opentofu binary + each vendor's module and runs `tofu init` + `plan`
(`--plan`) or `apply` (`--apply`) with per-project state at
`~/.platform-tfstate/<app>/<vendor>/`. Sensitive inputs are passed via `TF_VAR_*`
env (never argv). Default (no flag) is a non-executing readiness report.

**Clerk is intentionally not a Terraform module** — it has no public Management API
for app creation. The managed-auth pattern reuses shared per-env Clerk apps whose
keys live in `~/.platform-secrets/managed/clerk.env`; the CLI wires them into each
new app's `.env.local` directly.

## Planned layout

```
modules/
  vercel/        Vercel project + domain + env scopes
  datadog/       service, monitors, dashboards (applied as IaC)
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
