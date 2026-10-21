// Sample journey contracts covering every shape the tfvars contract can carry:
// P0/P1/P2 tiers, ratio and freshness SLIs, api/browser/freshness/exempt
// probes, the default 28-day window and explicit 7- and 90-day windows.
//
// Regenerate ../journeys.auto.tfvars.json (from a scratch directory, so no
// node_modules lands in this repo):
//
//   npm install @stabile/journeys@0.1.0
//   node /path/to/examples/journeys/sample/journeys.mjs > /path/to/examples/journeys/journeys.auto.tfvars.json
import { defineJourneys, emitTfvars, serializeTfvars } from "@stabile/journeys";

const journeys = defineJourneys({
  "AUTH.01": {
    tier: "P0",
    title: "Sign up",
    sli: {
      kind: "ratio",
      good: { metric: "auth.sign_up.attempt", tags: { outcome: "success" } },
      total: { metric: "auth.sign_up.attempt" },
    },
    probe: { kind: "browser", spec: "e2e/probes/sign-up.spec.ts" },
    runbook: "docs/runbooks/sign-up.md",
    severity: "S1",
    owner: "platform",
  },
  "AUTH.03": {
    tier: "P0",
    title: "Sign in",
    description: "A returning user signs in and lands on their dashboard.",
    sli: {
      kind: "ratio",
      good: { metric: "auth.sign_in.attempt", tags: { outcome: "success" } },
      total: { metric: "auth.sign_in.attempt" },
    },
    probe: { kind: "api", url: "https://app.example.com/api/probe/sign-in", method: "POST" },
    runbook: "docs/runbooks/sign-in.md",
    severity: "S1",
    owner: "platform",
  },
  "BILLING.01": {
    tier: "P0",
    title: "Billing gate redirects to checkout",
    sli: {
      kind: "ratio",
      good: { metric: "billing.gate", tags: { outcome: "redirected" } },
      total: { metric: "billing.gate" },
    },
    probe: { kind: "api", url: "https://app.example.com/billing", expectStatus: [302, 307] },
    runbook: "docs/runbooks/billing-gate.md",
    severity: "S2",
    owner: "platform",
  },
  "BG.SYNC.01": {
    tier: "P0",
    title: "Provider event synced",
    description: "A provider webhook is processed within 15 minutes.",
    sli: {
      kind: "freshness",
      withinMinutes: 15,
      lag: { metric: "sync.lag_seconds" },
      total: { metric: "sync.triggered", tags: { source: "webhook" } },
    },
    probe: { kind: "freshness", canary: "sync-canary" },
    runbook: "docs/runbooks/sync.md",
    severity: "S2",
    owner: "platform",
  },
  "INT.02": {
    tier: "P0",
    title: "Connect an OAuth integration",
    sli: {
      kind: "ratio",
      good: { metric: "integrations.oauth_callback", tags: { outcome: "success" } },
      total: { metric: "integrations.oauth_callback" },
    },
    probe: { kind: "exempt", reason: "third-party consent screen" },
    runbook: "docs/runbooks/oauth-connect.md",
    severity: "S2",
    owner: "platform",
  },
  "NOTES.02": {
    tier: "P1",
    title: "Edit a note",
    sli: {
      kind: "ratio",
      good: { metric: "notes.update", tags: { outcome: "success" } },
      total: { metric: "notes.update" },
    },
    runbook: "docs/runbooks/edit-note.md",
    severity: "S3",
  },
  "REPORTS.01": {
    tier: "P1",
    title: "Export a report",
    sli: {
      kind: "ratio",
      good: { metric: "reports.export", tags: { outcome: "success" } },
      total: { metric: "reports.export" },
    },
    slo: { target: 99, windowDays: 90 },
    runbook: "docs/runbooks/export-report.md",
    severity: "S3",
  },
  "SEARCH.01": {
    tier: "P2",
    title: "Search notes",
    sli: {
      kind: "ratio",
      good: { metric: "search.query", tags: { outcome: "success" } },
      total: { metric: "search.query" },
    },
    slo: { target: 98, windowDays: 7 },
  },
});

process.stdout.write(
  serializeTfvars(emitTfvars(journeys, { runbookBaseUrl: "https://github.com/example-org/example-app/blob/main/" })),
);
