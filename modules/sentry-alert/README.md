# modules/sentry-alert

Sentry issue-alert rules as code (`sentry_issue_alert`, using the provider's
`*_v2` attributes). Each rule is keyed by a stable slug, so changing its title
is an in-place update. A `severity` such as `S2` prefixes the name
(`[S2] …`), which puts the response SLA in every notification subject.

## Inputs

| Variable | Required | Notes |
|---|---|---|
| `organization` | yes | Sentry org slug |
| `project` | yes | Sentry project slug |
| `rules` | no | map of rule slug → rule (below) |

A rule is `title`, plus optional `severity`, `environment`,
`frequency_minutes` (default 30), `action_match` (default `any`),
`filter_match` (default `all`) and `owner`. It also takes three lists:
`conditions`, `filters` and `actions`. Each list entry sets exactly one kind:

```hcl
rules = {
  "auth-failure-spike" = {
    title      = "Authentication failure spike"
    severity   = "S2"
    conditions = [{ event_frequency = { value = 20, interval = "5m" } }]
    filters = [
      { tagged_event = { key = "http_method", match = "EQUAL", value = "POST" } },
      { tagged_event = { key = "route", match = "IS_IN", value = "/api/auth,/sign-in" } },
    ]
    actions = [{ notify_email = { target_type = "IssueOwners", fallthrough_type = "ActiveMembers" } }]
  }
}
```

Typed kinds:

- **conditions:** `event_frequency`, `event_unique_user_frequency`,
  `first_seen_event`, `regression_event`, `reappeared_event`,
  `new_high_priority_issue`, `existing_high_priority_issue`
- **filters:** `tagged_event`, `event_attribute`, `level`,
  `issue_occurrences`, `age_comparison`
- **actions:** `notify_email`, `slack_notify_service`,
  `pagerduty_notify_service`, `notify_event_service`

To support another kind, add it as an optional attribute in `variables.tf`.

## Moving rules from exported JSON

| Legacy JSON `id` | Here |
|---|---|
| `…event_frequency.EventFrequencyCondition` (`value`, `interval`) | `event_frequency = { value, interval }` |
| `…first_seen_event.FirstSeenEventCondition` | `first_seen_event = {}` |
| `…filters.tagged_event.TaggedEventFilter` (`key`, `match`, `value`) | `tagged_event = { key, match, value }`, where `match` is `eq` → `EQUAL`, `ne` → `NOT_EQUAL`, `sw` → `STARTS_WITH`, `ew` → `ENDS_WITH`, `co` → `CONTAINS`, `in` → `IS_IN`, `is` → `IS_SET` |
| `sentry.mail.actions.NotifyEmailAction` (`targetType`, `fallthroughType`) | `notify_email = { target_type, fallthrough_type }` |
| `frequency`, `environment`, `actionMatch`, `filterMatch` | `frequency_minutes`, `environment`, `action_match`, `filter_match` |

Adopt existing rules with an import block, so nothing is recreated:
`to = module.<name>.sentry_issue_alert.this["<slug>"]`,
`id = "<org>/<project>/<rule id>"`. See
[`docs/journey-monitoring.md`](../../docs/journey-monitoring.md).

## Outputs

`rule_ids`.

## Notes

- Provider 0.15 marks `sentry_issue_alert` deprecated in favour of
  `sentry_alert`, the newer workflow API. This module stays on
  `sentry_issue_alert` because existing rules import into it 1:1 by rule id.
  Moving to `sentry_alert` is a follow-up. The deprecation warning in
  `validate`/`plan` output is expected.
- Every resource has `prevent_destroy`.

## Validation status

✓ `tofu validate`, `tofu fmt`, `tofu test` (plan against a mocked provider).
Provider `jianyuan/sentry ~> 0.15` (0.15.8), OpenTofu 1.12.3. Not yet planned
against a real Sentry org.
