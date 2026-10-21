# App-specific inputs. `journeys_contract_version` and `slos` come from the
# emitted journeys.auto.tfvars.json (see examples/journeys).
service       = "example-app"
env           = "production"
query_tags    = { env = "production" }
page_notify   = ["@slack-ops-alerts-critical"]
ticket_notify = ["@slack-ops-alerts"]

# window_remaps = { "28" = "30d" }
