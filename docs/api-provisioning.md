# API-based provisioning (non-Terraform vendors)

Not every vendor has a usable Terraform provider. Three of the nine provision via
their REST APIs instead, in a CLI step that runs after the Terraform modules:

| Vendor | Why not Terraform | Provisioning path (planned) |
|---|---|---|
| **Stripe** | No official provider; community ones (`lukasaron`, `edgedb`, …) are unmaintained and risky for billing. | Stripe API: create test-mode product + price(s) from the app's `pricing` config. Idempotent on a deterministic lookup key. |
| **Resend** | No real provider (only low-download community forks). | Resend API: add the sending domain; emit the DNS records for the registrar step. |
| **Inngest** | No provider exists. | Inngest API / app-sync: register the app's signing + event keys. Often just env wiring. |

**Clerk** is a fourth non-Terraform vendor, but for a different reason: it has no
public Management API for app creation at all. The managed-auth pattern reuses the
shared per-env Clerk apps (keys in `~/.platform-secrets/managed/clerk.env`), so
there's nothing to provision per app — the CLI just injects the keys.

## CLI behavior today

The `@stabile/cli` provision step reports these vendors as
"token present (API-provisioned; no terraform module)" when their managed token is
set. The actual API calls are a Phase 2 follow-up (`lib/api-provision.ts`), gated
behind `--apply` like the Terraform path. Until then they're no-ops in the flow.

## Why this split is the right call

Forcing Terraform onto vendors without maintained providers would mean depending on
abandoned community code in the critical bootstrap path. API provisioning for these
three is simpler and more reliable than wrapping a dead provider.
