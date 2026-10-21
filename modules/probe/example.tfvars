# App-specific inputs. `journeys_contract_version` and `probes` come from the
# emitted journeys.auto.tfvars.json (see examples/journeys). Secrets
# (datadog_api_key, probe_request_headers) come from TF_VAR_* in CI, never a file.
service               = "example-app"
cloudflare_account_id = "0123456789abcdef0123456789abcdef"
datadog_site          = "datadoghq.com"
page_notify           = ["@slack-ops-alerts-critical"]
ticket_notify         = ["@slack-ops-alerts"]

# failure_alerts = true
