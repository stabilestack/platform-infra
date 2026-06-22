variable "name" {
  description = "Supabase project name."
  type        = string
}

variable "organization_id" {
  description = "Supabase organization id (slug) to create the project under."
  type        = string
}

variable "region" {
  description = "Project region."
  type        = string
  default     = "us-east-1"
}

variable "database_password" {
  description = "Postgres password for the project. The CLI generates one per app."
  type        = string
  sensitive   = true
}
