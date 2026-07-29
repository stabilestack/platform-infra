# modules/vercel

Provisions a Vercel project for a StabileStack app: the project itself, an
optional connected git repo, an optional managed-mode subdomain
(`<name>.platform.stabilestack.com`), and environment variables (plain + sensitive).

The bootstrap CLI calls this as the first vendor step (`@stabile/cli` provision
order: github → **vercel** → …), with per-project state at
`~/.platform-tfstate/<name>/vercel/`.

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `name` | yes | — | kebab-case project name |
| `team_id` | yes | — | platform team in managed mode |
| `framework` | no | `nextjs` | Vercel framework preset |
| `git_repository` | no | `null` | `{ type, repo, production_branch? }`, e.g. `{ type="github", repo="stabilestack/<name>" }` |
| `root_directory` | no | `null` | monorepo app dir, e.g. `apps/web` |
| `managed_domain` | no | `null` | `<name>.platform.stabilestack.com`; null in portable mode |
| `autopush_domain` | no | `null` | stable hostname for the autopush tier, e.g. `autopush.mannagame.com` |
| `autopush_branch` | no | `main` | branch the autopush domain follows |
| `automation_bypass` | no | `false` | issue a Deployment Protection bypass token for CI probes |
| `environment` | no | `{}` | plain env vars (both targets) |
| `sensitive_environment` | no | `{}` | redacted env vars (both targets) |
| `production_environment` | no | `{}` | plain env vars, `production` target only |
| `production_sensitive_environment` | no | `{}` | redacted env vars, `production` target only |
| `preview_environment` | no | `{}` | plain env vars, `preview` target only |
| `preview_sensitive_environment` | no | `{}` | redacted env vars, `preview` target only |

The per-scope maps back the **production tier** (STA-2): the `production`
deployment gets prod credentials (Clerk prod app, prod Supabase, `STABILE_PROFILE=production`)
while `preview`/autopush deployments keep the shared autopush credentials. Vars
identical across tiers stay in `environment` / `sensitive_environment`.

`production_branch` + `autopush_domain` make those two scopes two separate
**places**. Without them Vercel treats the default branch as production and
auto-assigns the live domain, so a merged PR is in front of customers a minute
later and the preview scope has no address anyone can remember. Set
`production_branch = "production"` and `main` becomes the autopush deploy;
promoting is then `git push origin main:production`.

`autopush_domain` must be bound to a branch — that is why it is its own resource
rather than another entry in `domains`. A project-level domain follows
*production*, which would alias staging onto the live deployment and silently
undo the split.

`automation_bypass` exists because the autopush tier is a **preview** deployment,
and Vercel guards those behind an SSO login. An unauthenticated request gets a
302 to `vercel.com/sso-api`, so a smoke check that only asserts "responded"
grades a login redirect as a healthy site. With the token, automation sends
`x-vercel-protection-bypass: <secret>` and gets the app. The secret is read from
`automation_bypass_secret` (computed by Vercel, never supplied).

Off by default: the token is **project-wide**. It unlocks every protected
deployment on the project, PR previews included — not just the autopush
hostname. That is the only grain Vercel offers.

## Outputs

`project_id`, `project_name`, `managed_domain`, `domains`, `autopush_domain`, and
`automation_bypass_secret` (sensitive; null unless `automation_bypass = true`).

## Auth

The Vercel provider reads `VERCEL_API_TOKEN` from the environment (the CLI exports
it from `~/.platform-secrets/managed/vercel.env`'s `VERCEL_TOKEN`). No token is
committed.

## Validation status

✓ **`tofu validate` + `tofu fmt` clean** against provider `vercel/vercel ~> 5.0`
(5.3.0), OpenTofu 1.12.3. Validation against the real v5 schema corrected two
things from the first draft:

- Environment variables use the **plural** `vercel_project_environment_variables`
  resource (a set of `{ key, value, sensitive, target }` objects) rather than a
  `for_each` over a sensitive map — v5 makes `sensitive` a required per-variable
  field, and a sensitive map can't be a `for_each` source.
- `git_repository` is a nested **attribute** (`{ type, repo, ... }`), not a block.

Still to confirm at first real `apply` (needs a `VERCEL_API_TOKEN`): the actual
create against the Vercel API. `plan`/`apply` is not yet exercised — only the
config is validated.

## Manual apply (when tokens exist)

```bash
export VERCEL_API_TOKEN="$(grep '^VERCEL_TOKEN=' ~/.platform-secrets/managed/vercel.env | cut -d= -f2-)"
terraform -chdir=modules/vercel init
terraform -chdir=modules/vercel plan -var-file=example.tfvars
```
