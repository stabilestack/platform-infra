# modules/posthog

Creates a PostHog project for the app (`PostHog/posthog`).

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `name` | yes | — | project name |

## Outputs

`project_id`.

## Auth

Provider reads its API key + host from the env. The CLI passes `POSTHOG_API_KEY`
+ `POSTHOG_HOST` (defaults to `https://us.posthog.com`). **Confirm the exact env
var names + host against the provider docs before first apply** — the PostHog
provider is younger than the others.

## Validation status

✓ `tofu validate` + `tofu fmt` clean (provider `PostHog/posthog ~> 1.0`, 1.0.11;
OpenTofu 1.12.3). `plan`/`apply` not yet exercised (needs a personal API key).
