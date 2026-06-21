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

⚠ **Authored against provider `vercel/vercel ~> 5.0` (5.3.0 latest at authoring),
but not yet `terraform validate`d** — terraform/OpenTofu isn't installed in the
authoring environment. Before the first real apply: install terraform, run
`terraform init && terraform validate` here, and confirm the `vercel_project` /
`vercel_project_domain` / `vercel_project_environment_variable` schemas against
the v5 provider docs (the framework-based provider changed several attributes
from earlier majors). CI gains a `terraform validate` step when the apply path
lands.

## Manual apply (when tokens exist)

```bash
export VERCEL_API_TOKEN="$(grep '^VERCEL_TOKEN=' ~/.platform-secrets/managed/vercel.env | cut -d= -f2-)"
terraform -chdir=modules/vercel init
terraform -chdir=modules/vercel plan -var-file=example.tfvars
```
