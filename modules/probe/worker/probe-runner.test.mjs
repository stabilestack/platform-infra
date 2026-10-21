// Offline test for the probe runner: fetch is stubbed, nothing leaves the machine.
// Run: node modules/probe/worker/probe-runner.test.mjs
import assert from "node:assert/strict";

const mod = await import("./probe-runner.mjs");

const calls = [];
globalThis.fetch = async (url, init) => {
  calls.push({ url, init });
  if (url.includes("datadoghq")) return new Response("{}", { status: 202 });
  if (url.includes("sign-in")) return new Response("ok", { status: 200 });
  if (url.includes("billing")) return new Response(null, { status: 302 });
  throw new Error("connect failed");
};

const env = {
  PROBES: {
    "AUTH.03": { url: "https://app.example.com/sign-in", method: "POST", expect_status: [200], interval_minutes: 5 },
    "BILLING.01": { url: "https://app.example.com/billing", method: "GET", expect_status: [302, 307], interval_minutes: 5 },
    "DOWN.01": { url: "https://down.example.com/", method: "GET", expect_status: [200], interval_minutes: 5 },
    "SLOW.01": { url: "https://app.example.com/sign-in", method: "GET", expect_status: [200], interval_minutes: 15 },
  },
  PROBE_HEADERS: JSON.stringify({ "AUTH.03": { authorization: "Bearer x" } }),
  DD_API_KEY: "k", DD_SITE: "us5.datadoghq.com", METRIC_PREFIX: "journey.probe", SERVICE: "example-app", ENV: "production", TIMEOUT_MS: "1000",
};

const pending = [];
// A tick on a 5-minute boundary that is not a 15-minute one: SLOW.01 must not run.
const t = Date.UTC(2026, 9, 20, 12, 5);
await mod.default.scheduled({ scheduledTime: t }, env, { waitUntil: (p) => pending.push(p) });
await Promise.all(pending);

const dd = calls.find((c) => c.url === "https://api.us5.datadoghq.com/api/v2/series");
assert.ok(dd, "submits to the configured site");
assert.equal(dd.init.headers["dd-api-key"], "k");
const series = JSON.parse(dd.init.body).series;
const success = Object.fromEntries(series.filter((s) => s.metric === "journey.probe.success").map((s) => [s.tags[0], s.points[0].value]));
assert.deepEqual(success, { "journey:auth.03": 1, "journey:billing.01": 1, "journey:down.01": 0 });
assert.equal(calls.find((c) => c.url.endsWith("/sign-in") && c.init.method === "POST").init.headers.authorization, "Bearer x");
assert.equal(calls.find((c) => c.url.endsWith("/billing")).init.redirect, "manual");
assert.ok(series[0].tags.includes("service:example-app") && series[0].tags.includes("env:production"));
console.log("worker ok:", success);
