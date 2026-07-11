# Consumption Logic App workflow shells keyed by name: identity, typed parameters, access control
# (IP restrictions plus AAD open authentication on the trigger), and the hidden-title tag the
# Libre DevOps Logic App standard requires. Workflow content (triggers and actions) is authored as
# raw azurerm_logic_app_trigger_* / azurerm_logic_app_action_* resources against these ids, per
# the standard: content is inherently per-playbook and separate resources give explicit
# depends_on ordering. The retired Integration Service Environment is deliberately not exposed.
# The resource group is passed by id and parsed.
locals {
  rg      = provider::azurerm::parse_resource_id(var.resource_group_id)
  rg_name = local.rg.resource_group_name

  # Typed parameters split into their two provider-level halves. Inputs arrive as strings (the
  # provider's parameters attribute is a string map anyway); the DEFINITION must carry real JSON
  # types, so defaults and allowed values are converted back per the declared type here.
  workflow_parameter_definitions = {
    for wf_name, wf in var.workflows : wf_name => {
      for p_name, p in wf.parameters : p_name => jsonencode(merge(
        { type = p.type },
        p.default != null ? {
          defaultValue = (
            contains(["Int", "Float"], p.type) ? tonumber(p.default) : (
              p.type == "Bool" ? p.default == "true" : (
                contains(["Object", "Array"], p.type) ? jsondecode(p.default) : p.default
              )
            )
          )
        } : {},
        p.allowed_values != null ? {
          allowedValues = [
            for s in p.allowed_values :
            contains(["Int", "Float"], p.type) ? tonumber(s) : (
              p.type == "Bool" ? s == "true" : (
                contains(["Object", "Array"], p.type) ? jsondecode(s) : s
              )
            )
          ]
        } : {},
        p.description != null ? { metadata = { description = p.description } } : {},
      ))
    }
  }

  # Every workflow with connections gets the boilerplate $connections definition.
  workflow_parameter_definitions_full = {
    for wf_name, wf in var.workflows : wf_name => merge(
      local.workflow_parameter_definitions[wf_name],
      length(local.effective_connections[wf_name]) > 0 ? { "$connections" = jsonencode({ type = "Object", defaultValue = {} }) } : {},
    )
  }

  # Values pass through as the strings the provider wants (Object/Array values are already
  # jsonencode(...) output by the input convention). The connections map generates the entire
  # $connections parameter, the shape managed connector action bodies reference as
  # @parameters('$connections')['<api name>']['connectionId'].
  # Effective connections: the shared estate set merged under each workflow's own (same-key
  # workflow entries win); a workflow with use_shared_connections = false keeps only its own.
  effective_connections = {
    for wf_name, wf in var.workflows : wf_name => merge(
      wf.use_shared_connections ? var.shared_connections : {},
      wf.connections,
    )
  }

  connections_parameter = {
    for wf_name, wf in var.workflows : wf_name => jsonencode({
      for api_name, c in local.effective_connections[wf_name] : api_name => merge(
        {
          connectionId   = c.connection_id
          connectionName = coalesce(c.connection_name, api_name)
          id             = c.managed_api_id
        },
        c.managed_identity_auth ? {
          connectionProperties = {
            authentication = merge(
              { type = "ManagedServiceIdentity" },
              wf.connections_identity_id != null ? { identity = wf.connections_identity_id } : {},
            )
          }
        } : {},
      )
    }) if length(local.effective_connections[wf_name]) > 0
  }

  workflow_parameter_values = {
    for wf_name, wf in var.workflows : wf_name => merge(
      { for p_name, p in wf.parameters : p_name => p.value if p.value != null },
      contains(keys(local.connections_parameter), wf_name) ? { "$connections" = local.connections_parameter[wf_name] } : {},
    )
  }
}

resource "azurerm_logic_app_workflow" "this" {
  for_each = var.workflows

  resource_group_name = local.rg_name
  location            = var.location
  # The title is not optional furniture: hidden-title is what the portal renders as the subtitle,
  # and the standard requires it on every Logic App.
  tags = merge(var.tags, coalesce(each.value.tags, {}), { "hidden-title" = each.value.title })

  name    = each.key
  enabled = each.value.enabled

  workflow_parameters = local.workflow_parameter_definitions_full[each.key]
  parameters          = local.workflow_parameter_values[each.key]

  workflow_schema                  = each.value.workflow_schema
  workflow_version                 = each.value.workflow_version
  logic_app_integration_account_id = each.value.integration_account_id

  identity {
    type         = each.value.identity.type
    identity_ids = each.value.identity.identity_ids
  }

  dynamic "access_control" {
    for_each = each.value.access_control != null ? [each.value.access_control] : []

    content {
      dynamic "action" {
        for_each = access_control.value.action_allowed_ips != null ? [access_control.value.action_allowed_ips] : []

        content {
          allowed_caller_ip_address_range = action.value
        }
      }

      dynamic "content" {
        for_each = access_control.value.content_allowed_ips != null ? [access_control.value.content_allowed_ips] : []

        content {
          allowed_caller_ip_address_range = content.value
        }
      }

      dynamic "workflow_management" {
        for_each = access_control.value.workflow_management_allowed_ips != null ? [access_control.value.workflow_management_allowed_ips] : []

        content {
          allowed_caller_ip_address_range = workflow_management.value
        }
      }

      dynamic "trigger" {
        for_each = access_control.value.trigger != null ? [access_control.value.trigger] : []

        content {
          allowed_caller_ip_address_range = trigger.value.allowed_ips

          dynamic "open_authentication_policy" {
            for_each = trigger.value.open_authentication_policies

            content {
              name = open_authentication_policy.key

              dynamic "claim" {
                for_each = open_authentication_policy.value.claims

                content {
                  name  = claim.key
                  value = claim.value
                }
              }
            }
          }
        }
      }
    }
  }
}

# The per-workflow diagnostic setting (allLogs to Log Analytics) every production playbook carries;
# named diag-<workflow> per the naming convention unless overridden.
resource "azurerm_monitor_diagnostic_setting" "this" {
  # The filter checks OBJECT presence (plan-known), never the workspace id value (unknown when the
  # workspace is created in the same apply): for_each keys must stay plan-known.
  for_each = {
    for k, w in var.workflows : k => (
      w.diagnostics != null ? w.diagnostics : { log_analytics_workspace_id = var.diagnostics.log_analytics_workspace_id, name = null }
    ) if w.diagnostics_enabled && (w.diagnostics != null || var.diagnostics != null)
  }

  name                       = coalesce(each.value.name, "diag-${each.key}")
  target_resource_id         = azurerm_logic_app_workflow.this[each.key].id
  log_analytics_workspace_id = each.value.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
