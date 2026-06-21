# modules/datadog

Registers a StabileStack app as a Datadog service (`datadog_service_definition_yaml`,
schema v2.2) and, optionally, a baseline log error-rate monitor.

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `service` | yes | — | kebab-case service name (the app's `DD_SERVICE`) |
| `team` | no | `""` | owning Datadog team handle |
| `env` | no | `production` | monitor env tag |
| `tier` | no | `""` | service-definition tier label |
| `notify` | no | `[]` | targets appended to the monitor message, e.g. `["@slack-alerts"]` |
| `monitor_enabled` | no | `true` | create the baseline monitor |
| `monitor_critical` | no | `10` | error-log count over 5m that trips it |

## Outputs

`service`, `monitor_id`.

## Auth & region

Provider reads `DD_API_KEY` + `DD_APP_KEY` from the env. **Confirm the account's
region** when wiring apply — set the provider `api_url` (US1 `api.datadoghq.com`
is the default; other sites differ). The CLI exports keys from
`~/.platform-secrets/managed/datadog.env`.

## Validation status

✓ `tofu validate` + `tofu fmt` clean (provider `DataDog/datadog ~> 4.0`, 4.13.0;
OpenTofu 1.12.3). `plan`/`apply` not yet exercised (needs DD keys).
