output "access_endpoints" {
  description = "Map of workflow name to its access endpoint."
  value       = { for k, v in azurerm_logic_app_workflow.this : k => v.access_endpoint }
}

output "connector_outbound_ip_addresses" {
  description = "Map of workflow name to the outbound IPs its managed connectors call from (for allow-listing on downstream firewalls)."
  value       = { for k, v in azurerm_logic_app_workflow.this : k => v.connector_outbound_ip_addresses }
}

output "identities" {
  description = "Map of workflow name to its identity { principal_id, tenant_id } (principal_id is populated for system-assigned identities), for role assignments."
  value = {
    for k, v in azurerm_logic_app_workflow.this : k => try({
      principal_id = v.identity[0].principal_id
      tenant_id    = v.identity[0].tenant_id
    }, null)
  }
}

output "ids" {
  description = "Map of workflow name to its resource id."
  value       = { for k, v in azurerm_logic_app_workflow.this : k => v.id }
}

output "ids_zipmap" {
  description = "Map of workflow name to a { name, id } object, for passing where both are needed together."
  value       = { for k, v in azurerm_logic_app_workflow.this : k => { name = v.name, id = v.id } }
}

output "names" {
  description = "The workflow names."
  value       = keys(azurerm_logic_app_workflow.this)
}

output "resource_group_name" {
  description = "Resource group name parsed from resource_group_id."
  value       = local.rg_name
}

output "subscription_id" {
  description = "Subscription id parsed from resource_group_id."
  value       = local.rg.subscription_id
}

output "tags" {
  description = "The base tags applied to the workflows."
  value       = var.tags
}

output "workflow_outbound_ip_addresses" {
  description = "Map of workflow name to the outbound IPs the workflow runtime calls from (for allow-listing on downstream firewalls)."
  value       = { for k, v in azurerm_logic_app_workflow.this : k => v.workflow_outbound_ip_addresses }
}
