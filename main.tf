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
  capabilities {
    name = "EnableServerless"
  }
}
resource "azurerm_cosmosdb_table" "panduhz-tbl" {
  name                = "azurerm"
  resource_group_name = azurerm_cosmosdb_account.panduhz-db.resource_group_name
  account_name        = azurerm_cosmosdb_account.panduhz-db.name
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "panduhz-workspace"
  location            = azurerm_resource_group.backend-rg.location
  resource_group_name = azurerm_resource_group.backend-rg.name
  sku                 = "PerGB2018"
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
#Logic App for Slack Message
resource "azurerm_logic_app_workflow" "slack_notifier" {
  name                = "SlackNotifier"
  location            = azurerm_resource_group.backend-rg.location
  resource_group_name = azurerm_resource_group.backend-rg.name
}
resource "azurerm_logic_app_trigger_http_request" "slack_trigger" {
  name         = "http-trigger"
  logic_app_id = azurerm_logic_app_workflow.slack_notifier.id

  schema = <<SCHEMA
{
  "$schema": "http://json-schema.org/draft-04/schema#",
  "type": "object",
  "properties": {
    "message": {
      "type": "string"
    }
  },
  "required": ["message"]
}
SCHEMA
}
variable "SLACK_BOT_TOKEN" {
  type = string
}
resource "azurerm_logic_app_action_http" "post_to_slack" {
  name         = "post-to-slack"
  logic_app_id = azurerm_logic_app_workflow.slack_notifier.id
  method       = "POST"
  uri          = "https://slack.com/api/chat.postMessage"

  headers = {
    "Authorization" = "Bearer ${var.SLACK_BOT_TOKEN}"
    "Content-Type"  = "application/json"
  }

  body = jsonencode({
    channel = "testing"
    text    = "@{triggerBody()['message']}"
  })
}

#Action group to send slack message, sms message, email, and push notif
resource "azurerm_monitor_action_group" "example" {
  name                = "PanduhzAlertAction"
  resource_group_name = azurerm_resource_group.backend-rg.name
  short_name          = "l1action"
  webhook_receiver {
    name        = "send_to_slack"
    service_uri = azurerm_logic_app_trigger_http_request.slack_trigger.callback_url
    use_common_alert_schema = true
  }
  azure_app_push_receiver {
    name          = "pushtoadmin"
    email_address = "christopherchannn@gmail.com"
  }
  sms_receiver {
    name         = "pushtophone"
    country_code = "1"
    phone_number = "6265607176"
  }
  email_receiver {
    name          = "emailtoadmin"
    email_address = "christopherchannn@gmail.com"
  }
}
resource "azurerm_monitor_metric_alert" "alert1" {
  name                = "alert1-logalert"
  resource_group_name = azurerm_resource_group.backend-rg.name
  scopes              = [azurerm_application_insights.panduhzinsight.id]
  description         = "If there are 10 requests in a minute"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/count"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 10
    dimension {
      name     = "request/resultCode"
      operator = "Include"
      values   = ["*"]
    }
  }
  action {
    action_group_id = azurerm_monitor_action_group.example.id
  }
}
resource "azurerm_monitor_metric_alert" "alert2" {
  name                = "alert2-logalert"
  resource_group_name = azurerm_resource_group.backend-rg.name
  scopes              = [azurerm_application_insights.panduhzinsight.id]
  description         = "Alert if avg response times are greater than 2 seconds"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = "2000"
  }
  action {
    action_group_id = azurerm_monitor_action_group.example.id
  }
}
#creating linux function app resource
resource "azurerm_linux_function_app" "crcbackend" {
  depends_on          = [azurerm_cosmosdb_account.panduhz-db]
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
      allowed_origins = ["https://www.panduhzco.com"]
    }
    application_stack {
      python_version = 3.11
    }
  }
  app_settings = {
    CosmosConnectionString = azurerm_cosmosdb_account.panduhz-db.connection_strings[4]
  }
  #declaring source files
  #zip_deploy_file = "/src/"
}

output "cosmosdb_connectionstrings" {
  value     = azurerm_cosmosdb_account.panduhz-db.connection_strings[4]
  sensitive = true
}
