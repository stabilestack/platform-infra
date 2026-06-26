output "project_id" {
  description = "Supabase project ref/id."
  value       = supabase_project.this.id
}

output "project_name" {
  description = "Supabase project name."
  value       = supabase_project.this.name
}

# Sensitive — within the local-state trust boundary (see platform CLAUDE.md
# "Secrets in Terraform state — accepted"). Lets the graduate flow rebuild the
# existing tier's pooler URL (the password isn't otherwise retrievable from the
# Supabase API) when routing it to the Preview Vercel scope.
output "database_password" {
  description = "The project's database password (as provisioned)."
  value       = var.database_password
  sensitive   = true
}
