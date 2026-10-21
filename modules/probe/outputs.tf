output "worker_name" {
  description = "Name of the probe runner Worker, or null when there are no api probes."
  value       = length(cloudflare_workers_script.runner) > 0 ? cloudflare_workers_script.runner[0].script_name : null
}

output "stale_monitor_ids" {
  description = "Staleness monitor id per journey id."
  value       = { for id, m in datadog_monitor.stale : id => m.id }
}

output "failing_monitor_ids" {
  description = "Failure monitor id per journey id (empty when failure_alerts is off)."
  value       = { for id, m in datadog_monitor.failing : id => m.id }
}
