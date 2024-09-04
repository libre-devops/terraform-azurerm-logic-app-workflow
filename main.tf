resource "azurerm_logic_app_workflow" "workflows" {
  for_each = {for app in var.logic_app_workflows : app.name => app}

  location                           = each.value.location
  name                               = each.value.name
  resource_group_name                = each.value.rg_name
  tags                               = each.value.tags
  integration_service_environment_id = each.value.integration_service_environment_id
  logic_app_integration_account_id   = each.value.logic_app_integration_account_id
  enabled                            = each.value.enabled
  workflow_parameters                = each.value.workflow_parameters
  workflow_version                   = each.value.workflow_version
  parameters                         = each.value.parameters


  dynamic "identity" {
    for_each = each.value.identity_type == "SystemAssigned" ? [each.value.identity_type] : []
    content {
      type = each.value.identity_type
    }
  }

  dynamic "identity" {
    for_each = each.value.identity_type == "UserAssigned" ? [each.value.identity_type] : []
    content {
      type         = each.value.identity_type
      identity_ids = length(try(each.value.identity_ids, [])) > 0 ? each.value.identity_ids : []
    }
  }

  dynamic "access_control" {
    for_each = each.value.access_control != null ? [each.value.access_control] : []
    content {
      dynamic "action" {
        for_each = access_control.value.action != null ? [access_control.value.action] : []
        content {
          allowed_caller_ip_address_range = action.value.allowed_caller_ip_address_range
        }
      }

      dynamic "content" {
        for_each = access_control.value.content != null ? [access_control.value.content] : []
        content {
          allowed_caller_ip_address_range = content.value.allowed_caller_ip_address_range
        }
      }

      dynamic "trigger" {
        for_each = access_control.value.trigger != null ? [access_control.value.trigger] : []
        content {
          allowed_caller_ip_address_range = trigger.value.allowed_caller_ip_address_range

          dynamic "open_authentication_policy" {
            for_each = trigger.value.open_authentication_policy != null ? [trigger.value.open_authentication_policy] : []
            content {
              name = open_authentication_policy.value.name

              dynamic "claim" {
                for_each = open_authentication_policy.value.claim != null ? [open_authentication_policy.value.claim] :
                  []
                content {
                  name  = claim.value.name
                  value = claim.value.value
                }
              }
            }
          }
        }
      }

      dynamic "workflow_management" {
        for_each = access_control.value.workflow_management != null ? [access_control.value.workflow_management] : []
        content {
          allowed_caller_ip_address_range = workflow_management.value.allowed_caller_ip_address_range
        }
      }
    }
  }
}
