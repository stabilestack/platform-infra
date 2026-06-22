# Creates a Supabase project for the app. Provider reads SUPABASE_ACCESS_TOKEN
# from the environment (set by the CLI from managed secrets).

resource "supabase_project" "this" {
  organization_id   = var.organization_id
  name              = var.name
  database_password = var.database_password
  region            = var.region

  lifecycle {
    # database_password can't be changed in place; ignore drift after create.
    ignore_changes = [database_password]
  }
}
