terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.96.0"
    }
  }
}
resource "azurerm_resource_group" "backend-rg" {
  name     = "panduhz_backend_rg"
  location = "westus2"
}
resource "azurerm_cosmosdb_account" "panduhz-db" {
  name                = "panduhz-counter-coosmosdb"
  location            = azurerm_resource_group.backend-rg.location
  resource_group_name = azurerm_resource_group.backend-rg.name
  offer_type          = "Standard"
  geo_location {
    location          = "westus2"
    failover_priority = 0
    zone_redundant    = false
  }
  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 86400
    max_staleness_prefix    = 1000000
  }
}
resource "azurerm_cosmosdb_table" "panduhz-tbl" {
  name                = "panduhz-table"
  resource_group_name = azurerm_cosmosdb_account.panduhz-db.resource_group_name
  account_name        = azurerm_cosmosdb_account.panduhz-db.name
  throughput          = 400
}
#need app service plan for linux function app
resource "azurerm_service_plan" "panduhzsrvc" {
  name                = "api-appserviceplan-pro"
  location            = azurerm_resource_group.backend-rg.location
  resource_group_name = azurerm_resource_group.backend-rg.name
  os_type             = "Linux"

  sku_name = "Y1"
}