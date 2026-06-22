output "full_name" {
  description = "owner/name of the created repository."
  value       = github_repository.this.full_name
}

output "http_clone_url" {
  description = "HTTPS clone URL."
  value       = github_repository.this.http_clone_url
}
