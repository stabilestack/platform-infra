terraform {
  required_version = ">= 1.6"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 4.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # A real app configures a remote backend here (state holds the probe
  # runner's secrets, so it must be private and encrypted). The example and
  # its tests run with local state only.
}
