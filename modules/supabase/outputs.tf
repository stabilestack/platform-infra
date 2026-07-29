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
# Reads the RESOURCE, not `var.database_password`. The variable is whatever the
# caller passed on THIS run, and callers generate a fresh random password every
# time; the resource attribute is what the project was actually created with,
# which the `ignore_changes` above pins (Supabase cannot change it in place).
# Echoing the variable meant a second apply published a password that opens
# nothing — the URL built from it landed in the Production Vercel scope and the
# app came up unable to reach its database. Cost mannagame.com a 500 on the first
# promote after graduating.
output "database_password" {
  description = "The project's database password, as the project was actually created with."
  value       = supabase_project.this.database_password
  sensitive   = true
}
