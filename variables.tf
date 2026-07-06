variable "diagnostics_log_analytics_workspace_id" {
  description = "When set, every workflow gets an allLogs diagnostic setting to this workspace (named diag-<workflow>) unless it sets its own diagnostics or opts out with diagnostics_enabled = false."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for the workflows."
  type        = string
}

variable "resource_group_id" {
  description = "Resource id of the resource group the workflows are created in. The resource group name and subscription are parsed from this id."
  type        = string

  validation {
    condition     = try(provider::azurerm::parse_resource_id(var.resource_group_id).resource_type, "") == "resourceGroups"
    error_message = "resource_group_id must be a resource group resource id."
  }
}

variable "shared_connections" {
  description = "API connections shared by every workflow in the call (the usual estate shape: the same Sentinel/Monitor/ITSM connections on every playbook), keyed by managed API name. Merged under each workflow's own connections (same-key workflow entries win); a workflow opts out with use_shared_connections = false."
  type = map(object({
    connection_id         = string
    connection_name       = optional(string)
    managed_api_id        = string
    managed_identity_auth = optional(bool, false)
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to the workflows (merged with per-workflow tags; the workflow's title always lands as the hidden-title tag)."
  type        = map(string)
  default     = {}
}

variable "workflows" {
  description = <<-EOT
    Consumption Logic App workflows (Microsoft.Logic/workflows) keyed by name
    (logic-ldo-uks-prd-001). The workflow content (triggers and actions) is authored as raw
    azurerm_logic_app_trigger_* / azurerm_logic_app_action_* resources per the Libre DevOps Logic
    App standard; this module owns the shell. Fields:
      title       REQUIRED human-readable description, becomes the hidden-title tag the portal
                  renders as the resource subtitle ("{Trigger type} - {what it does}").
      parameters  Typed workflow parameters, the no-hardcoding path. Each entry generates BOTH the
                  workflow parameter definition (type, defaultValue, description, allowedValues)
                  AND its deployment value, so content only ever references
                  @parameters('name'). Types: String, SecureString, Int, Float, Bool, Object,
                  Array, SecureObject. Values are strings (Terraform coerces numbers and bools, so
                  value = 25 works; Object and Array values pass jsonencode(...), the same rule
                  the standard sets for all workflow JSON); the module converts defaults and
                  allowed values back to their real JSON types in the definition. Secure types
                  must not set default or allowed_values (their definitions are readable by anyone
                  with Reader).
      identity    SystemAssigned by default; UserAssigned supported.
      connections API connections for the workflow's managed connectors, keyed by the managed API
                  name the action bodies reference. Generates the entire $connections parameter
                  pair (definition and value: connectionId, connectionName, id, and the
                  ManagedServiceIdentity authentication block when managed_identity_auth is true),
                  so bodies keep saying
                  @parameters('$connections')['<api name>']['connectionId'] with zero hand-rolled
                  JSON.
      diagnostics Optional per-workflow diagnostic setting (allLogs) to a Log Analytics workspace,
                  named diag-<workflow> unless overridden.
      access_control  IP restrictions for action/content/workflow_management, and for the trigger
                  additionally AAD open authentication policies (claims like iss/aud/appid), the
                  right way to let an action group or app call an HTTP trigger without shared
                  SAS exposure.
      enabled, workflow_schema, workflow_version, integration_account_id  Pass-throughs.
    The retired Integration Service Environment (integration_service_environment_id) is
    deliberately not exposed.
  EOT
  type = map(object({
    title   = string
    enabled = optional(bool, true)
    tags    = optional(map(string))

    identity = optional(object({
      type         = optional(string, "SystemAssigned")
      identity_ids = optional(set(string))
    }), {})

    parameters = optional(map(object({
      type           = string
      value          = optional(string)
      default        = optional(string)
      description    = optional(string)
      allowed_values = optional(list(string))
    })), {})

    connections = optional(map(object({
      connection_id         = string
      connection_name       = optional(string)
      managed_api_id        = string
      managed_identity_auth = optional(bool, false)
    })), {})
    use_shared_connections = optional(bool, true)

    diagnostics = optional(object({
      log_analytics_workspace_id = string
      name                       = optional(string)
    }))
    diagnostics_enabled = optional(bool, true)

    access_control = optional(object({
      action_allowed_ips              = optional(list(string))
      content_allowed_ips             = optional(list(string))
      workflow_management_allowed_ips = optional(list(string))
      trigger = optional(object({
        allowed_ips = optional(list(string), [])
        open_authentication_policies = optional(map(object({
          claims = map(string)
        })), {})
      }))
    }))

    workflow_schema        = optional(string)
    workflow_version       = optional(string)
    integration_account_id = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for w in values(var.workflows) : length(trimspace(w.title)) > 0])
    error_message = "every workflow needs a non-empty title: it becomes the hidden-title tag the portal shows as the resource subtitle."
  }

  validation {
    condition = alltrue(flatten([
      for w in values(var.workflows) : [
        for p in values(w.parameters) : contains(["String", "SecureString", "Int", "Float", "Bool", "Object", "Array", "SecureObject"], p.type)
      ]
    ]))
    error_message = "parameter type must be one of String, SecureString, Int, Float, Bool, Object, Array, SecureObject."
  }

  validation {
    condition = alltrue(flatten([
      for w in values(var.workflows) : [
        for p in values(w.parameters) :
        contains(["SecureString", "SecureObject"], p.type) ? (p.default == null && p.allowed_values == null) : true
      ]
    ]))
    error_message = "secure parameters (SecureString, SecureObject) must not set default or allowed_values: parameter definitions are readable by anyone with Reader on the workflow."
  }

  validation {
    condition = alltrue(flatten([
      for w in values(var.workflows) : [
        for p in values(w.parameters) : p.value != null || p.default != null
      ]
    ]))
    error_message = "every parameter needs a value (or a default for non-secure types): a declared parameter with neither fails at runtime."
  }

  validation {
    condition = alltrue(flatten([
      for w in values(var.workflows) : [
        for p in values(w.parameters) : [
          for s in compact([p.value, p.default]) :
          contains(["Int", "Float"], p.type) ? can(tonumber(s)) : (
            p.type == "Bool" ? contains(["true", "false"], s) : (
              contains(["Object", "Array", "SecureObject"], p.type) ? can(jsondecode(s)) : true
            )
          )
        ]
      ]
    ]))
    error_message = "parameter values and defaults must match their declared type: numbers for Int/Float, \"true\"/\"false\" for Bool, and jsonencode(...) output for Object/Array/SecureObject."
  }

  validation {
    condition     = alltrue([for w in values(var.workflows) : !contains(keys(w.parameters), "$connections")])
    error_message = "do not declare the $connections parameter yourself: the connections map generates it."
  }

  validation {
    condition     = alltrue([for w in values(var.workflows) : contains(["SystemAssigned", "UserAssigned"], w.identity.type)])
    error_message = "identity.type must be SystemAssigned or UserAssigned (the workflow resource does not support both at once)."
  }
}
