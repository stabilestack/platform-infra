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

output "autopush_domain" {
  description = "The autopush tier's hostname, if one was attached."
  value       = var.autopush_domain
}

# Reads the RESOURCE — the value Vercel generated and will honour on the
# `x-vercel-protection-bypass` header. Same rule the supabase module learned the
# hard way: an output that exists to say what a resource IS must read the resource.
#
# Sensitive, and inside the local-state trust boundary (platform CLAUDE.md,
# "Secrets in Terraform state — accepted"). Null when no bypass was issued.
output "automation_bypass_secret" {
  description = "Automation bypass token for Deployment Protection, or null when automation_bypass is false."
  value       = var.automation_bypass ? vercel_project_protection_bypass.automation[0].secret : null
  sensitive   = true
}
