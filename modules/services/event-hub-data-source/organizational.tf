data "azurerm_client_config" "current" {}

data "azurerm_management_group" "onboarded_management_group" {
  for_each = length(var.management_group_ids) > 0 ? toset(var.management_group_ids) : toset([data.azurerm_client_config.current.tenant_id])
  name     = each.value
}

locals {
  all_mg_subscription_ids = flatten([
    for mg in data.azurerm_management_group.onboarded_management_group : mg.all_subscription_ids
  ])
}

data "azurerm_subscription" "onboarded_subscriptions" {
  for_each = toset(local.all_mg_subscription_ids)
  subscription_id = each.value
}

locals { 
    enabled_subscriptions = var.is_organizational ? [for s in data.azurerm_subscription.onboarded_subscriptions : s if s.state == "Enabled"] : []
}

#---------------------------------------------------------------------------------------------
# Create diagnostic settings for the tenant
#---------------------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "sysdig_org_diagnostic_setting" {
  count = var.is_organizational ? length(local.enabled_subscriptions) : 0

  name               = var.diagnostic_settings_name
  target_resource_id = local.enabled_subscriptions[count.index].id
  eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.sysdig_rule.id
  eventhub_name                  = azurerm_eventhub.sysdig_event_hub.name

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Policy"
  }
}