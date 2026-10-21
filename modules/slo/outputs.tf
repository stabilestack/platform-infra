output "slo_ids" {
  description = "Datadog SLO id per journey id."
  value       = { for id, s in datadog_service_level_objective.this : id => s.id }
}

output "burn_rate_monitor_ids" {
  description = "Burn-rate monitor id per \"<journey id>/<page|ticket>\"."
  value       = { for k, m in datadog_monitor.burn_rate : k => m.id }
}

output "timeframes" {
  description = "Per journey: the contract's window_days, the Datadog timeframe used, and whether it was remapped."
  value = {
    for id, s in local.slos : id => {
      window_days = s.window_days
      timeframe   = s.timeframe
      remapped    = s.remapped
    }
  }
}
