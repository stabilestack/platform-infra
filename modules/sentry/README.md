# modules/sentry

Creates a Sentry project for a StabileStack app and exposes its public DSN.

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `organization` | yes | — | Sentry org slug |
| `team` | yes | — | team slug that owns the project |
| `name` | yes | — | project name |
| `slug` | no | `null` | project slug (derived from `name` when null) |
| `platform` | no | `javascript-nextjs` | Sentry platform id |

## Outputs

`project_slug`, `dsn_public` (marked sensitive — provider contract; the public
DSN ships in client code).

## Auth

Provider (`jianyuan/sentry`) reads `SENTRY_AUTH_TOKEN` from the env. The CLI
exports it from `~/.platform-secrets/managed/sentry.env`.

## Validation status

✓ `tofu validate` + `tofu fmt` clean (provider `jianyuan/sentry ~> 0.15`, 0.15.2;
OpenTofu 1.12.3). The default DSN reads via `data.sentry_key.default.dsn["public"]`
(the `dsn_public` attribute is deprecated in this provider). `plan`/`apply` not
yet exercised (needs a Sentry token + a real org/team).
