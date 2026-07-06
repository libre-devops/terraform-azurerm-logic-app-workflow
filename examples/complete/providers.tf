provider "azurerm" {
  features {
    # A Sentinel-onboarded workspace left soft-deleted blocks name reuse for 14 days; the E2E
    # applies and destroys the same names every run, so destroy must purge.
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }

  storage_use_azuread = true
  use_oidc            = true
}

provider "azapi" {
  use_oidc = true
}
