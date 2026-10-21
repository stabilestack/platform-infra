# modules/probe

External journey probes, kept cheap. A Cloudflare Worker on a 5-minute cron
trigger runs the `api` probes from outside the app's hosting. It pushes each
result to Datadog as `journey.probe.success` (1/0) and
`journey.probe.duration_ms`. Every probe gets a Datadog **staleness**
monitor, and by default a **failure** monitor. This replaces Datadog
Synthetics: the target is $0–5/month, against roughly $250–300. Wiring,
keys, metric contract and imports are in
[`docs/journey-monitoring.md`](../../docs/journey-monitoring.md).

## Input contract

`journeys_contract_version` and `probes` come from the
`journeys.auto.tfvars.json` that `@stabile/journeys` emits (contract v1). Pass
them through unchanged.

- `api` probes run in the Worker. Each is one request (`method`, `url`), and
  it passes when the status is in `expect_status`. Redirects are not
  followed.
- `browser` probes run in the app's scheduled Playwright job, which must push
  the same metrics. This module only monitors them.
- `interval_minutes` must be a multiple of 5 for `api` probes.
  `stale_after_minutes` must be at least 10.

## What the runner holds

Only `probe_request_headers` (the probe user's credentials, per journey) and
`datadog_api_key`: a dedicated Datadog **API** key, which can submit metrics
and nothing else. The key and headers are Worker secrets. They also sit in
Terraform state, so the state backend must be private.

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `journeys_contract_version` | yes | — | must be `1` |
| `probes` | yes | — | from the tfvars |
| `service` | yes | — | tags metrics and monitors |
| `cloudflare_account_id` | yes | — | |
| `datadog_api_key` | when any `api` probe exists | `null` | sensitive; submission-only |
| `probe_request_headers` | no | `{}` | sensitive; `{ "<journey id>" = { header = value } }` |
| `env` | no | `production` | |
| `worker_name` | no | `<service>-journey-probes` | |
| `datadog_site` | no | `datadoghq.com` | e.g. `us5.datadoghq.com` |
| `compatibility_date` | no | `2026-10-01` | Workers runtime |
| `timeout_ms` | no | `10000` | per request |
| `metric_prefix` | no | `journey.probe` | |
| `failure_alerts` | no | `true` | failure monitor per probe |
| `page_notify` / `ticket_notify` | no | `[]` | P0 failures page; staleness and P1+ failures ticket |
| `validate_queries` | no | `true` | |

## Outputs

`worker_name` (null without `api` probes), `stale_monitor_ids`,
`failing_monitor_ids`.

## Validation status

✓ `tofu validate`, `tofu fmt`, `tofu test` (plan against mocked providers),
and `node worker/probe-runner.test.mjs` (runner logic with `fetch` stubbed).
Providers `DataDog/datadog ~> 4.0` (4.26.0) and `cloudflare/cloudflare ~> 5.0`
(5.28.0), OpenTofu 1.12.3. Not yet deployed to a real Cloudflare account.
