output "project_slug" {
  description = "The created Sentry project slug."
  value       = sentry_project.this.slug
}

output "dsn_public" {
  description = "Public DSN the app reports events to."
  value       = data.sentry_key.default.dsn["public"]
  # Provider marks dsn values sensitive; the public DSN ships in client code so
  # this is conservative, but the contract requires the annotation.
  sensitive = true
}
