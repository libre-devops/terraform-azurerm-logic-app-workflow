output "workflow_identities" {
  description = "System-assigned identity principals of the workflows."
  value       = module.logic_app_workflow.identities
}

output "workflow_ids" {
  description = "Map of workflow name to resource id."
  value       = module.logic_app_workflow.ids
}
