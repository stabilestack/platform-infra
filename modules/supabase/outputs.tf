output "project_id" {
  description = "Supabase project ref/id."
  value       = supabase_project.this.id
}

output "project_name" {
  description = "Supabase project name."
  value       = supabase_project.this.name
}
