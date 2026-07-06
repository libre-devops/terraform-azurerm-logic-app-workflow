output "action_group_ids" {
  description = "The action group the storm rule notifies."
  value       = module.action_group.ids
}

output "storm_rule_id" {
  description = "The scheduled query rule detecting the storm."
  value       = azurerm_monitor_scheduled_query_rules_alert_v2.alert_storm.id
}

output "workflow_ids" {
  description = "Map of workflow name to resource id."
  value       = module.logic_app_workflow.ids
}
