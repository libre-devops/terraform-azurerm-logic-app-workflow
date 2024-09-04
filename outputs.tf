output "logic_app_workflow_access_endpoints" {
  description = "The Access Endpoints for the Logic App Workflows."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.access_endpoint }
}

output "logic_app_workflow_connector_endpoint_ip_addresses" {
  description = "The list of access endpoint IP addresses of connector."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.connector_endpoint_ip_addresses }
}

output "logic_app_workflow_connector_outbound_ip_addresses" {
  description = "The list of outgoing IP addresses of connector."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.connector_outbound_ip_addresses }
}

output "logic_app_workflow_endpoint_ip_addresses" {
  description = "The list of access endpoint IP addresses of workflow."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.workflow_endpoint_ip_addresses }
}

output "logic_app_workflow_identity" {
  description = "The identities for the Logic App Workflows."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.identity }
}

output "logic_app_workflow_ids" {
  description = "The Logic App Workflow IDs."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.id }
}

output "logic_app_workflow_names" {
  description = "The Logic App Workflow names"
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.name }
}

output "logic_app_workflow_outbound_ip_addresses" {
  description = "The list of outgoing IP addresses of workflow."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.workflow_outbound_ip_addresses }
}

output "logic_app_workflow_principal_ids" {
  description = "The Principal IDs for the Service Principal associated with the Managed Service Identity of this Logic App Workflow."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => try(workflow.identity[0].principal_id, null) }
}

output "logic_app_workflow_rg_names" {
  description = "The Logic App Workflow resource group names"
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.resource_group_name }
}

output "logic_app_workflow_tags" {
  description = "The Logic App Workflow resource group names"
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => workflow.tags }
}

output "logic_app_workflow_tenant_ids" {
  description = "The Tenant IDs for the Service Principal associated with the Managed Service Identity of this Logic App Workflow."
  value       = { for name, workflow in azurerm_logic_app_workflow.workflows : name => try(workflow.identity[0].tenant_id, null) }
}
