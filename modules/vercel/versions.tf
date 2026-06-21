terraform {
  required_version = ">= 1.6"

  required_providers {
    vercel = {
      source = "vercel/vercel"
      # Provider major confirmed against the registry at authoring time (5.3.0).
      version = "~> 5.0"
    }
  }
}
