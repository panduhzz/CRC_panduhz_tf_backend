terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.96.0"
    }
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "backend-rg" {
  name     = "panduhz_backend_rg"
  location = "westus2"
}
#backend storage account for function app
resource "azurerm_storage_account" "bestorageacct" {
  name                     = "panduhzbestorage"
  resource_group_name      = azurerm_resource_group.backend-rg.name
  location                 = azurerm_resource_group.backend-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
resource "azurerm_cosmosdb_account" "panduhz-db" {
  name                = "panduhz-counter-cosmosdb"
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
  capabilities {
    name = "EnableTable"
  }
}
resource "azurerm_cosmosdb_table" "panduhz-tbl" {
  name                = "panduhz-table"
  resource_group_name = azurerm_cosmosdb_account.panduhz-db.resource_group_name
  account_name        = azurerm_cosmosdb_account.panduhz-db.name
  throughput          = 400
}
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "panduhz-workspace"
  location            = azurerm_resource_group.backend-rg.location
  resource_group_name = azurerm_resource_group.backend-rg.name
  sku                 = "Standard"
  retention_in_days   = 30
}
#creating an application insights resource for our function app to view logs
resource "azurerm_application_insights" "panduhzinsight" {
  name                = "panduhz-app-insight"
  resource_group_name = azurerm_resource_group.backend-rg.name
  location            = azurerm_resource_group.backend-rg.location
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  application_type    = "web"
}
#need app service plan for linux function app
resource "azurerm_service_plan" "panduhzsrvc" {
  name                = "api-appserviceplan-pro"
  location            = azurerm_resource_group.backend-rg.location
  resource_group_name = azurerm_resource_group.backend-rg.name
  os_type             = "Linux"

  sku_name = "Y1"
}
#creating linux function app resource
resource "azurerm_linux_function_app" "crcbackend" {
  name                = "backend-function-app"
  resource_group_name = azurerm_resource_group.backend-rg.name
  location            = azurerm_resource_group.backend-rg.location
  #using backend storage account
  storage_account_name       = azurerm_storage_account.bestorageacct.name
  storage_account_access_key = azurerm_storage_account.bestorageacct.primary_access_key
  service_plan_id            = azurerm_service_plan.panduhzsrvc.id

  site_config {
    application_insights_connection_string = azurerm_application_insights.panduhzinsight.connection_string
    application_insights_key               = azurerm_application_insights.panduhzinsight.instrumentation_key
    cors {
      allowed_origins = [ "https://www.panduhzco.com" ]
    }
    application_stack {
      python_version = 3.11
    }
  }
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = 1
  }
  #declaring source files
  #zip_deploy_file = "/src/"
}