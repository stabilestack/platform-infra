# modules/slo

Compiles journey contracts to Datadog. Each journey gets a metric SLO
(`datadog_service_level_objective`) and one `slo alert` burn-rate monitor per
burn alert the contract derives. P0 gets **page** at 14.4x over 1h, confirmed
over 5m, and **ticket** at 6x over 6h, confirmed over 30m. P1 gets the ticket
alert only. P2/P3 get no alerts. Wiring, keys, imports and deletion are in
[`docs/journey-monitoring.md`](../../docs/journey-monitoring.md).

## Input contract

`journeys_contract_version` and `slos` are the keys of the
`journeys.auto.tfvars.json` that `@stabile/journeys` emits (contract v1). Pass
them through unchanged. The module rejects any other contract version. It
also rejects a page alert on a non-P0 journey and a slos key that differs
from its `journey_id`. Keys the emitter adds without a version bump are
ignored.

| SLI kind | Numerator | Denominator |
|---|---|---|
| `ratio` | `sum:<good.metric>{<tags>}.as_count()` | `sum:<total.metric>{<tags>}.as_count()` |
| `freshness` | `count(v: v<=<within_seconds>):<lag.metric>{<tags>}.as_count()` (distribution threshold query) | `sum:<total.metric>{<tags>}.as_count()` |

`<tags>` is the contract's tags merged over `query_tags`, or `*` when both are
empty. A freshness `lag` metric must be a distribution with percentiles
enabled.

## Inputs

| Variable | Required | Default | Notes |
|---|---|---|---|
| `journeys_contract_version` | yes | — | from the tfvars; must be `1` |
| `slos` | yes | — | from the tfvars |
| `service` | yes | — | tags every SLO and monitor |
| `env` | no | `production` | tag |
| `query_tags` | no | `{}` | filters added to every SLI query, e.g. `{ env = "production" }` |
| `window_remaps` | no | `{ "28" = "30d" }` | Datadog SLOs only support 7d/30d/90d; any other unmapped window fails the plan |
| `page_notify` | no | `[]` | handles for page alerts |
| `ticket_notify` | no | `[]` | handles for ticket alerts |
| `tags` | no | `[]` | extra tags |
| `validate_queries` | no | `true` | Datadog validates queries at plan time; tests turn it off |

## Outputs

`slo_ids`, `burn_rate_monitor_ids` (keyed `"<journey id>/<page|ticket>"`),
`timeframes` (per journey: `window_days`, `timeframe`, `remapped`).

## Addresses

`datadog_service_level_objective.this["<journey id>"]` and
`datadog_monitor.burn_rate["<journey id>/<action>"]`. Every resource has
`prevent_destroy`.

## Validation status

✓ `tofu validate`, `tofu fmt`, and `tofu test` (plan against a mocked
provider; `tests/`). Provider `DataDog/datadog ~> 4.0` (4.26.0), OpenTofu
1.12.3. Not yet planned against a real Datadog account.
