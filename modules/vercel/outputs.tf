output "project_id" {
  description = "Vercel project id — stable reference the CLI records per app."
  value       = vercel_project.this.id
}

output "project_name" {
  description = "Vercel project name."
  value       = vercel_project.this.name
}

output "managed_domain" {
  description = "The managed subdomain attached, if any."
  value       = var.managed_domain
}

output "domains" {
  description = "Every domain attached to the project, managed subdomain included."
  value = concat(
    var.managed_domain == null ? [] : [var.managed_domain],
    sort(var.domains),
  )
}
