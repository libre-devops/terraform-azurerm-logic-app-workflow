provider "azurerm" {
  features {}

  storage_use_azuread = true
  use_oidc            = true
}

provider "azapi" {
  use_oidc = true
}
