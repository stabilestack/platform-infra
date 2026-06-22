# modules/github

Creates the app's GitHub repository (`integrations/github`).

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `name` | yes | — | repo name (kebab-case) |
| `description` | no | `""` | repo description |
| `visibility` | no | `private` | `private` / `public` / `internal` |

## Outputs

`full_name` (owner/name), `http_clone_url`.

## Auth

Provider reads `GITHUB_TOKEN` + `GITHUB_OWNER` from the env (set by the CLI from
managed secrets). No provider block in the module so the root/CLI owns auth.

## Validation status

✓ `tofu validate` + `tofu fmt` clean (provider `integrations/github ~> 6.0`,
6.12.1; OpenTofu 1.12.3). `plan`/`apply` not yet exercised (needs a GitHub token).
