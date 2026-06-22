terraform {
  required_version = ">= 1.6"

  required_providers {
    posthog = {
      source  = "PostHog/posthog"
      version = "~> 1.0"
    }
  }
}
