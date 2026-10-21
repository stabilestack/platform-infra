# examples/journeys

The root module an app copies to wire its journey contracts to monitoring
(`modules/slo` + `modules/probe`). `journeys.auto.tfvars.json` here was
emitted by the published `@stabile/journeys@0.1.0` from
[`sample/journeys.mjs`](sample/journeys.mjs). The sample covers every shape
the v1 contract carries: P0/P1/P2, ratio and freshness SLIs,
api/browser/freshness/exempt probes, and the 28-day default plus explicit
7- and 90-day windows.

`tofu test` (in `tests/`) is the acceptance check that emitted tfvars plan
cleanly against the modules. It runs against mocked providers: no
credentials, nothing created. To regenerate the tfvars, see the header of
`sample/journeys.mjs`.

Setup for a real app (backend, caller workflow, keys) is in
[`docs/journey-monitoring.md`](../../docs/journey-monitoring.md).
