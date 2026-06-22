# modules/supabase

Creates a Supabase project for the app (`supabase/supabase`).

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `name` | yes | — | project name |
| `organization_id` | yes | — | Supabase org id/slug |
| `region` | no | `us-east-1` | project region |
| `database_password` | yes (sensitive) | — | the CLI generates one per app and passes it via `TF_VAR_database_password` (never on argv) |

## Outputs

`project_id` (ref), `project_name`.

## Auth

Provider reads `SUPABASE_ACCESS_TOKEN` from the env (set by the CLI from managed
secrets).

## Notes

`database_password` can't be changed in place — the resource uses
`lifecycle.ignore_changes` on it so a regenerated value doesn't force a diff.

## Validation status

✓ `tofu validate` + `tofu fmt` clean (provider `supabase/supabase ~> 1.0`, 1.9.1;
OpenTofu 1.12.3). `plan`/`apply` not yet exercised (needs an access token + a real
org id).
