# Creates the app's GitHub repository. The provider's owner + token come from the
# environment (GITHUB_OWNER / GITHUB_TOKEN), set by the CLI from managed secrets —
# no provider block here so the root/CLI controls auth.

resource "github_repository" "this" {
  name        = var.name
  description = var.description
  visibility  = var.visibility
  auto_init   = true

  has_issues   = true
  has_projects = false
  has_wiki     = false
}
