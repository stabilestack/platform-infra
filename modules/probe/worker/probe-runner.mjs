// Journey probe runner: a Cloudflare Worker on a cron trigger, so it runs
// outside the app's hosting and still reports when that hosting is down.
//
// Each tick it runs the API probes that are due, then pushes one result per
// probe to Datadog as gauges:
//   <prefix>.success      1 if the status was expected, else 0
//   <prefix>.duration_ms  request time, success or not
// tagged journey:<id, lowercased>, probe_kind:api, probe_runner:cloudflare,
// service:<service>, env:<env>. The `probe` module's monitors query exactly
// these names and tags.
//
// Bindings (all set by the module):
//   PROBES         json         { [journeyId]: { url, method, expect_status, interval_minutes } }
//   PROBE_HEADERS  secret_text  JSON { [journeyId]: { header: value } }: the probe user's credentials
//   DD_API_KEY     secret_text  a Datadog API key (metric submission only; never an app key)
//   DD_SITE, METRIC_PREFIX, SERVICE, ENV, TIMEOUT_MS   plain_text

const USER_AGENT = "stabilestack-journey-probe/1";

export default {
  async scheduled(controller, env, ctx) {
    ctx.waitUntil(run(controller.scheduledTime, env));
  },
};

async function run(scheduledTime, env) {
  const probes = env.PROBES ?? {};
  const headers = env.PROBE_HEADERS ? JSON.parse(env.PROBE_HEADERS) : {};
  const timeoutMs = Number(env.TIMEOUT_MS ?? 10000);
  const minute = Math.round(scheduledTime / 60000);

  const due = Object.entries(probes).filter(([, p]) => minute % p.interval_minutes === 0);
  const results = await Promise.all(due.map(([id, p]) => probe(id, p, headers[id] ?? {}, timeoutMs)));
  if (results.length > 0) await submit(results, env, Math.floor(scheduledTime / 1000));

  const failed = results.filter((r) => !r.ok);
  if (failed.length > 0) {
    console.log(JSON.stringify({ msg: "probe failures", failed }));
  }
}

async function probe(id, p, headers, timeoutMs) {
  const started = Date.now();
  try {
    // Redirects are results, not hops: a probe may assert the 302 itself.
    const res = await fetch(p.url, {
      method: p.method,
      headers: { "user-agent": USER_AGENT, ...headers },
      redirect: "manual",
      signal: AbortSignal.timeout(timeoutMs),
    });
    await res.body?.cancel();
    return { id, ok: p.expect_status.includes(res.status), status: res.status, ms: Date.now() - started };
  } catch (err) {
    return { id, ok: false, status: 0, error: String(err), ms: Date.now() - started };
  }
}

async function submit(results, env, timestamp) {
  const prefix = env.METRIC_PREFIX;
  const series = results.flatMap((r) => {
    const tags = [
      `journey:${r.id.toLowerCase()}`,
      "probe_kind:api",
      "probe_runner:cloudflare",
      `service:${env.SERVICE}`,
      `env:${env.ENV}`,
    ];
    return [
      { metric: `${prefix}.success`, type: 3, points: [{ timestamp, value: r.ok ? 1 : 0 }], tags },
      { metric: `${prefix}.duration_ms`, type: 3, points: [{ timestamp, value: r.ms }], tags },
    ];
  });

  const res = await fetch(`https://api.${env.DD_SITE}/api/v2/series`, {
    method: "POST",
    headers: { "content-type": "application/json", "dd-api-key": env.DD_API_KEY },
    body: JSON.stringify({ series }),
  });
  if (!res.ok) {
    // Throwing marks the invocation failed in Cloudflare; the staleness
    // monitor is what tells a human.
    throw new Error(`Datadog series submit failed: ${res.status} ${await res.text()}`);
  }
}
