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
| `git_repository` | no | `null` | `{ type, repo }`, e.g. `{ type="github", repo="stabilestack/<name>" }` |
| `root_directory` | no | `null` | monorepo app dir, e.g. `apps/web` |
| `managed_domain` | no | `null` | `<name>.platform.stabilestack.com`; null in portable mode |
| `environment` | no | `{}` | plain env vars (all targets) |
| `sensitive_environment` | no | `{}` | redacted env vars (all targets) |

## Outputs

`project_id`, `project_name`, `managed_domain`.

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
