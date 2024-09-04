```hcl
resource "azurerm_logic_app_workflow" "workflows" {
  for_each = { for app in var.logic_app_workflows : app.name => app }

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
                for_each = open_authentication_policy.value.claim != null ? [open_authentication_policy.value.claim] : []
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
```
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_logic_app_workflow.workflows](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_workflow) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_logic_app_workflows"></a> [logic\_app\_workflows](#input\_logic\_app\_workflows) | The list of object settings for logic app workflows | <pre>list(object({<br>    name                               = string<br>    rg_name                            = string<br>    location                           = string<br>    tags                               = map(string)<br>    enabled                            = optional(bool, true)<br>    integration_service_environment_id = optional(string)<br>    logic_app_integration_account_id   = optional(string)<br>    identity_type                      = optional(string)<br>    identity_ids                       = optional(list(string))<br>    workflow_schema                    = optional(string)<br>    workflow_parameters                = optional(map(string))<br>    workflow_version                   = optional(string, "1.0.0.0")<br>    parameters                         = optional(map(string))<br>    access_control = optional(object({<br>      action = optional(object({<br>        allowed_caller_ip_address_range = list(string)<br>      }))<br>      content = optional(object({<br>        allowed_caller_ip_address_range = list(string)<br>      }))<br>      trigger = optional(object({<br>        allowed_caller_ip_address_range = list(string)<br>        open_authentication_policy = optional(object({<br>          name = string<br>          claim = optional(object({<br>            name  = string<br>            value = string<br>          }))<br>        }))<br>      }))<br>      workflow_management = optional(object({<br>        allowed_caller_ip_address_range = list(string)<br>      }))<br>    }))<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_logic_app_workflow_access_endpoints"></a> [logic\_app\_workflow\_access\_endpoints](#output\_logic\_app\_workflow\_access\_endpoints) | The Access Endpoints for the Logic App Workflows. |
| <a name="output_logic_app_workflow_connector_endpoint_ip_addresses"></a> [logic\_app\_workflow\_connector\_endpoint\_ip\_addresses](#output\_logic\_app\_workflow\_connector\_endpoint\_ip\_addresses) | The list of access endpoint IP addresses of connector. |
| <a name="output_logic_app_workflow_connector_outbound_ip_addresses"></a> [logic\_app\_workflow\_connector\_outbound\_ip\_addresses](#output\_logic\_app\_workflow\_connector\_outbound\_ip\_addresses) | The list of outgoing IP addresses of connector. |
| <a name="output_logic_app_workflow_endpoint_ip_addresses"></a> [logic\_app\_workflow\_endpoint\_ip\_addresses](#output\_logic\_app\_workflow\_endpoint\_ip\_addresses) | The list of access endpoint IP addresses of workflow. |
| <a name="output_logic_app_workflow_identity"></a> [logic\_app\_workflow\_identity](#output\_logic\_app\_workflow\_identity) | The identities for the Logic App Workflows. |
| <a name="output_logic_app_workflow_ids"></a> [logic\_app\_workflow\_ids](#output\_logic\_app\_workflow\_ids) | The Logic App Workflow IDs. |
| <a name="output_logic_app_workflow_names"></a> [logic\_app\_workflow\_names](#output\_logic\_app\_workflow\_names) | The Logic App Workflow names |
| <a name="output_logic_app_workflow_outbound_ip_addresses"></a> [logic\_app\_workflow\_outbound\_ip\_addresses](#output\_logic\_app\_workflow\_outbound\_ip\_addresses) | The list of outgoing IP addresses of workflow. |
| <a name="output_logic_app_workflow_principal_ids"></a> [logic\_app\_workflow\_principal\_ids](#output\_logic\_app\_workflow\_principal\_ids) | The Principal IDs for the Service Principal associated with the Managed Service Identity of this Logic App Workflow. |
| <a name="output_logic_app_workflow_rg_names"></a> [logic\_app\_workflow\_rg\_names](#output\_logic\_app\_workflow\_rg\_names) | The Logic App Workflow resource group names |
| <a name="output_logic_app_workflow_tags"></a> [logic\_app\_workflow\_tags](#output\_logic\_app\_workflow\_tags) | The Logic App Workflow resource group names |
| <a name="output_logic_app_workflow_tenant_ids"></a> [logic\_app\_workflow\_tenant\_ids](#output\_logic\_app\_workflow\_tenant\_ids) | The Tenant IDs for the Service Principal associated with the Managed Service Identity of this Logic App Workflow. |
