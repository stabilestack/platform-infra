# Journey monitoring: contracts to Terraform

An app declares its critical user journeys with `@stabile/journeys`
(`defineJourneys`). `journeys emit` compiles them to
`journeys.auto.tfvars.json`, and three modules here turn that file and the
app's Sentry rules into live monitoring:

| Module | Creates | Input |
|---|---|---|
| [`modules/slo`](../modules/slo) | a Datadog SLO per journey, plus its burn-rate monitors (P0: page + ticket, P1: ticket) | `slos` from the tfvars |
| [`modules/probe`](../modules/probe) | a Cloudflare Workers cron runner for `api` probes; a staleness monitor and a failure monitor per probe | `probes` from the tfvars |
| [`modules/sentry-alert`](../modules/sentry-alert) | Sentry issue-alert rules | `rules`, written by hand |

Nobody applies from a laptop. CI plans every PR and posts the plan as a
comment. It applies from `main` after merge, and a nightly plan reports drift.
Every resource carries `lifecycle { prevent_destroy = true }`.

## Wiring an app

1. **Emit.** The app's CI already runs `journeys emit --check`, so the committed
   tfvars always matches the contracts.
2. **Root module.** Copy [`examples/journeys`](../examples/journeys) into the
   app (e.g. `monitoring/`). Point each `source` at a pinned ref:
   `github.com/stabilestack/platform-infra//modules/slo?ref=<tag>`. Configure a
   remote backend there. State holds the probe runner's secrets, so the
   backend must be private and encrypted. Any S3-compatible bucket works,
   including Cloudflare R2 ([below](#state-on-cloudflare-r2)).
3. **Caller workflow** in the app repo:

   ```yaml
   name: monitoring
   on:
     pull_request:
       paths: ["monitoring/**"]
     push:
       branches: [main]
       paths: ["monitoring/**"]
     schedule:
       - cron: "17 6 * * *" # nightly drift check
     workflow_dispatch:

   jobs:
     monitoring:
       uses: stabilestack/platform-infra/.github/workflows/journey-monitoring.yml@<tag>
       with:
         mode: ${{ github.event_name == 'pull_request' && 'plan' || (github.event_name == 'push' && 'apply' || 'drift') }}
         working-directory: monitoring
       secrets: inherit
       permissions:
         contents: read
         pull-requests: write
         issues: write
   ```

   Set `paths` to wherever the emitted tfvars lives, so a contract change
   triggers a plan.

   platform-infra is private, so two things must be in place before an
   app's CI can use it:
   - **Workflow access.** In platform-infra, set *Settings → Actions →
     General → Access* to "Accessible from repositories in the stabilestack
     organization". Without it, the `uses:` line above fails.
   - **Module access.** `tofu init` fetches the module sources over git, and
     the job's own `GITHUB_TOKEN` can't read another private repo. Add
     `PLATFORM_INFRA_READ_TOKEN` (below). The workflow turns it into a git
     credential scoped to `github.com/stabilestack/`.

## Keys: plan reads, only apply writes

Configure the same secret names at two levels:

| Secret | Repo level (plan, drift) | `monitoring-apply` environment (apply) |
|---|---|---|
| `DD_API_KEY` | API key | API key |
| `DD_APP_KEY` | app key scoped to read monitors and SLOs | app key with monitor and SLO write |
| `CLOUDFLARE_API_TOKEN` | Workers Scripts: Read | Workers Scripts: Edit |
| `SENTRY_AUTH_TOKEN` | read-only token | `alerts:write` token |
| `TF_STATE_ACCESS_KEY_ID` / `TF_STATE_SECRET_ACCESS_KEY` | state bucket | state bucket |
| `PROBE_DATADOG_API_KEY` | (only needed to plan the runner) | dedicated API key the runner submits metrics with |
| `PROBE_REQUEST_HEADERS` | JSON `{ "<journey id>": { "<header>": "<value>" } }` | same |
| `PLATFORM_INFRA_READ_TOKEN` | fine-grained token with Contents: Read on `stabilestack/platform-infra` | same |

The apply job declares `environment: monitoring-apply`, and environment
secrets override repo secrets of the same name. Restrict that environment to
`main` under *Settings → Environments → Deployment branches*. Add required
reviewers if a human should approve each apply. Fork PRs get no secrets, so
their plan fails; that is expected.

The probe runner holds two secrets: the probe user's credentials
(`PROBE_REQUEST_HEADERS`) and a Datadog **API** key, which can only submit
data. It never holds an app key, a production database URL or a vendor
admin token.

## State on Cloudflare R2

R2 is a supported backend through OpenTofu's `s3` backend:

```hcl
terraform {
  backend "s3" {
    bucket = "<app>-tofu-state"
    key    = "monitoring/terraform.tfstate"
    region = "auto"
    endpoints = {
      s3 = "https://<cloudflare account id>.r2.cloudflarestorage.com"
    }

    # R2 isn't AWS: skip the AWS-only checks.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true

    use_path_style = true
    use_lockfile   = true # lock object in the bucket; no DynamoDB
  }
}
```

Create an R2 API token with **Object Read & Write**, scoped to this one
bucket only (not "all buckets", never Admin). Its Access Key ID and Secret
Access Key go in `TF_STATE_ACCESS_KEY_ID` / `TF_STATE_SECRET_ACCESS_KEY`.

R2 has no object versioning, so a bad state write can't be rolled back from
the bucket. The apply job covers that with snapshots (next section).

## State snapshots and restore

Every apply pulls the state just before and just after `tofu apply` and
uploads each as an Actions artifact on that run, kept 90 days:

- `tofu-state-<run id>-<attempt>-<working dir>-pre`
- `tofu-state-<run id>-<attempt>-<working dir>-post`

On the first apply there is no state yet, so `pre` is an empty file. `post`
is uploaded even when the apply fails, since a partial apply still writes
state.

**These artifacts contain secrets.** State holds the probe runner's
`PROBE_REQUEST_HEADERS` and Datadog API key. They are uploaded only by the
main-branch apply, never on `pull_request` runs. Anyone with read access to
the app repo can download them, so the app repo must stay private; artifact
access follows repo visibility and there is nothing else to configure.

**Restore** (a human with state access, never CI):

1. From the apply run that preceded the bad write, download the artifact you
   want, usually that run's `post` (or the bad run's `pre`):
   `gh run download <run id> -n <artifact name> -D /tmp/state-restore`
2. With the state keys exported, in the root module:
   ```sh
   tofu init
   tofu state push /tmp/state-restore/<pre|post>.tfstate
   ```
   `state push` refuses a snapshot with a different lineage or a lower
   serial than the remote state, which a rollback always has. Add `-force`
   only after checking the snapshot is the one you mean.
3. Delete the local copy, then run the monitoring workflow by hand
   (`workflow_dispatch` runs the drift plan) to confirm the plan is clean.

## Datadog SLO windows

Datadog SLOs support 7-, 30- and 90-day windows only. The contracts default to
28 days, so `modules/slo` maps 28 to `30d` (`window_remaps`, default
`{ "28" = "30d" }`). Any other unsupported window fails the plan rather than
being guessed. The `timeframes` output shows every mapping.

## Freshness SLIs need a distribution metric with percentiles

A freshness SLI counts `lag` samples at or under `within_seconds` with a
Datadog threshold query (`count(v: v<=900):<lag metric>{…}`). Threshold
queries only work on a **distribution** metric with percentiles / advanced
query functionality enabled (*Metrics → Summary → the metric → Advanced*).
These modules don't manage that setting. Enable it once per lag metric, or the
SLO plan fails validation.

## Probes

- **`api` probes** run in the Cloudflare Worker every 5 minutes, outside the
  app's hosting. Each probe is one request: `method` to `url`. It passes when
  the status is in `expect_status`. Redirects are not followed, so a probe can
  assert a 302.
- **`browser` probes** run in the app's scheduled Playwright job. That job
  must push the same metrics as the Worker, or its probes stay stale:
  - `journey.probe.success`: gauge, 1 or 0
  - `journey.probe.duration_ms`: gauge
  - tags `journey:<id lowercased>`, `service:<service>`, `env:<env>`, `probe_kind:browser`
- **Staleness monitor** (all probes): alerts when nothing has arrived for
  `stale_after_minutes`. It always tickets, because a silent probe is a
  monitoring fault.
- **Failure monitor** (all probes, `failure_alerts = true`): alerts when every
  run in the last `stale_after_minutes` failed. For a 5-minute API probe that
  means 3 consecutive failures. P0 pages; P1 and lower ticket.

Cost: one Worker, one cron trigger, and about 288 runs a day per app. That
fits the Workers free tier (100k requests/day, 5 cron triggers per account).
Workers Paid ($5/month) lifts the cron-trigger and subrequest limits. On the
free plan an invocation can make 50 subrequests, which is about 45 `api`
probes per app.

## Adopting hand-made monitors (`terraform import`)

Adopt existing objects with **import blocks** in a PR, never with a local
`tofu import`. The plan comment then shows exactly what will be adopted, and
CI performs the adoption on apply like any other change. Nothing is
recreated, so alert history and monitor ids survive.

**An SLO or monitor these modules now generate** (e.g. a hand-made SLO for a
journey that now has a contract): add to the app's root module

```hcl
import {
  to = module.slo.datadog_service_level_objective.this["AUTH.03"]
  id = "<datadog slo id>"
}
import {
  to = module.slo.datadog_monitor.burn_rate["AUTH.03/page"]
  id = "<datadog monitor id>"
}
```

The plan should say `1 to import` with an in-place update at most, since
names, tags and queries converge to the contract. A plan that wants to
*replace* the object means the import target is wrong; stop there.

**A hand-made monitor no contract describes** (the general case):

1. Add one import block per monitor, addressed to a new resource in the
   root module:
   ```hcl
   import {
     to = datadog_monitor.checkout_latency
     id = "12345678"
   }
   ```
2. Locally, with read-only keys, generate the matching configuration:
   `tofu plan -generate-config-out=imported_monitors.tf`. This only reads.
3. Add `lifecycle { prevent_destroy = true }` to every generated resource.
   Tidy the generated config as needed.
4. Open the PR. The plan comment must show only imports and no changes.
   Merge; CI applies the imports.
5. After the apply, delete the import blocks, along with any JSON export or
   script the monitors used to live in.

Import ids for other resources:

| Resource | Import id |
|---|---|
| `datadog_monitor`, `datadog_service_level_objective` | the Datadog id |
| `sentry_issue_alert` | `<org>/<project>/<rule id>` |
| `cloudflare_workers_script` | `<account id>/<script name>` |
| `cloudflare_workers_cron_trigger` | `<account id>/<script name>` |

## Deleting something

`prevent_destroy` makes any plan that would destroy a guarded resource fail.
That failure is the guard working. What a human does next depends on where
the resource lives:

- **A resource in the app's own root module** (e.g. an adopted monitor):
  open a PR that removes its `prevent_destroy` line and the resource
  together. The plan shows the destroy, and a human approves the PR.
- **One journey's generated SLO, monitor or probe.** Removing the contract
  makes the plan fail. The guard sits inside the shared module and
  `prevent_destroy` can't take a variable, so it can't be lifted for a single
  instance. A human with state access runs
  `tofu state rm 'module.slo.datadog_service_level_objective.this["X.01"]'`
  (and the same for its `burn_rate` monitors), then re-runs the PR plan,
  which is now clean, and merges. Finally, delete the orphaned object in
  Datadog by hand, or keep it for history.
- **Renaming a journey id** is a delete plus a create, so it takes the same
  path. Pick ids you won't need to change.
