output "service" {
  description = "The registered Datadog service name."
  value       = var.service
}

output "monitor_id" {
  description = "Id of the baseline error-rate monitor, or null when disabled."
  value       = var.monitor_enabled ? datadog_monitor.errors[0].id : null
}
