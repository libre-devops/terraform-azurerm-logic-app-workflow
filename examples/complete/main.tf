locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name   = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  ag_name    = "ag-${var.short}-${var.loc}-${terraform.workspace}-002"
  logic_name = "logic-${var.short}-${var.loc}-${terraform.workspace}-002"
  conn_name  = "conn-sentinel-${var.short}-${var.loc}-${terraform.workspace}-002"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-logic-app-workflow" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# Sentinel-onboarded workspace, so seeded incidents land in SecurityIncident for the storm rule
# to count. Destroy note: a Sentinel-onboarded workspace must be purged with
# az monitor log-analytics workspace delete --force, never left soft-deleted.
module "law" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = {
    (local.law_name) = { onboard_to_sentinel = true }
  }
}

# Our own Sentinel API connection (the estate default; most playbooks share it), created the
# standard's way: azapi on Microsoft.Web/connections with parameterValueType Alternative for
# managed identity auth, plus an access policy granting the workflow's identity use of it.
data "azurerm_managed_api" "sentinel" {
  name     = "azuresentinel"
  location = local.location
}

resource "azapi_resource" "sentinel_connection" {
  type                      = "Microsoft.Web/connections@2016-06-01"
  name                      = local.conn_name
  parent_id                 = module.rg.ids[local.rg_name]
  location                  = local.location
  tags                      = module.tags.tags
  schema_validation_enabled = false

  body = {
    properties = {
      displayName        = local.conn_name
      parameterValueType = "Alternative"
      api = {
        id = data.azurerm_managed_api.sentinel.id
      }
    }
  }
}

# The access policy is what lets the workflow's managed identity use the connection at runtime.
resource "azapi_resource" "sentinel_connection_access" {
  type                      = "Microsoft.Web/connections/accessPolicies@2016-06-01"
  name                      = local.logic_name
  parent_id                 = azapi_resource.sentinel_connection.id
  location                  = local.location
  schema_validation_enabled = false

  body = {
    properties = {
      principal = {
        type = "ActiveDirectory"
        identity = {
          tenantId = module.logic_app_workflow.identities[local.logic_name].tenant_id
          objectId = module.logic_app_workflow.identities[local.logic_name].principal_id
        }
      }
    }
  }
}

# The alert-storm playbook: the workflow shell from this module (typed parameters, hidden-title,
# diagnostics), content as raw resources below, per the Libre DevOps Logic App standard.
module "logic_app_workflow" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  diagnostics_log_analytics_workspace_id = module.law.workspace_ids[local.law_name]

  # The estate default: one shared Sentinel connection every playbook in the call inherits.
  shared_connections = {
    "azuresentinel" = {
      connection_id         = azapi_resource.sentinel_connection.id
      connection_name       = local.conn_name
      managed_api_id        = data.azurerm_managed_api.sentinel.id
      managed_identity_auth = true
    }
  }

  workflows = {
    (local.logic_name) = {
      title = "HTTP - Summarise a Sentinel alert storm and notify the on-call webhook"

      parameters = {
        storm_threshold = {
          type        = "Int"
          value       = var.storm_threshold
          description = "Incidents per evaluation window that count as a storm (mirrors the alert rule threshold)."
        }
        notify_webhook_url = {
          type        = "SecureString"
          value       = var.notify_webhook_url
          description = "Webhook the storm summary is POSTed to."
        }
        notify_retry_count = {
          type        = "Int"
          value       = 3
          description = "Retry attempts for the notification POST before the catch path records the failure."
        }
      }

      # The action group calls the trigger with its SAS URL; the IP ranges of the alerting service
      # are not fixed, so the honest control here is the SAS plus this visible wide allow. Locking
      # to AAD via open_authentication_policies is shown in the module usage docs.
      access_control = {
        trigger = { allowed_ips = ["0.0.0.0/0"] }
      }
    }
  }
}

# ------------------------------------------------------------------------------------------------
# Workflow content (raw resources, per the standard): verbose names, a description on every
# action, explicit retry policy on the remote call, and a Scope try/catch so transient
# notification failures are handled rather than failing the run.
# ------------------------------------------------------------------------------------------------

# TRIGGER: the action group invokes this with the common alert schema payload.
resource "azurerm_logic_app_trigger_http_request" "storm_detected" {
  name         = "When_the_alert_storm_rule_fires_via_the_action_group"
  logic_app_id = module.logic_app_workflow.ids[local.logic_name]

  method = "POST"
  schema = file("${path.module}/templates/common-alert-schema.json")
}

# ACTION 1: distil the common alert schema payload into the storm summary all later steps use.
resource "azurerm_logic_app_action_custom" "compose_storm_summary" {
  name         = "Compose_-_Distil_the_common_alert_schema_into_a_storm_summary"
  logic_app_id = module.logic_app_workflow.ids[local.logic_name]

  body = jsonencode({
    description = "Builds the storm summary (rule, severity, window, threshold) from the common alert schema essentials."
    type        = "Compose"
    inputs = {
      alertRule      = "@{triggerBody()?['data']?['essentials']?['alertRule']}"
      severity       = "@{triggerBody()?['data']?['essentials']?['severity']}"
      firedDateTime  = "@{triggerBody()?['data']?['essentials']?['firedDateTime']}"
      stormThreshold = "@parameters('storm_threshold')"
      message        = "Sentinel incident volume crossed @{parameters('storm_threshold')} in the evaluation window."
    }
    runAfter = {}
  })

  depends_on = [azurerm_logic_app_trigger_http_request.storm_detected]
}

# ACTION 2: the try/catch scope around the notification POST. The body lives in a template so the
# retry policy and structure stay readable; the only Terraform interpolation is structural.
resource "azurerm_logic_app_action_custom" "try_notify_oncall" {
  name         = "Scope_-_Try_notifying_the_on_call_webhook_with_retries"
  logic_app_id = module.logic_app_workflow.ids[local.logic_name]

  body = templatefile("${path.module}/templates/try-notify-scope.json.tftpl", {
    summary_action_name = azurerm_logic_app_action_custom.compose_storm_summary.name
  })

  depends_on = [azurerm_logic_app_action_custom.compose_storm_summary]
}

# ACTION 3: the catch path, running only when the scope fails after its retries: record the
# failure so the run itself still succeeds and the storm is visible in run history either way.
resource "azurerm_logic_app_action_custom" "catch_record_notification_failure" {
  name         = "Compose_-_Record_that_notification_failed_after_retries"
  logic_app_id = module.logic_app_workflow.ids[local.logic_name]

  body = jsonencode({
    description = "Catch path: the notification POST failed after every retry; the failure is recorded and the run completes so storm evidence is never lost."
    type        = "Compose"
    inputs = {
      outcome = "notification-failed"
      scope   = "@{result('${azurerm_logic_app_action_custom.try_notify_oncall.name}')}"
    }
    runAfter = {
      (azurerm_logic_app_action_custom.try_notify_oncall.name) = ["Failed", "TimedOut"]
    }
  })
}

# ------------------------------------------------------------------------------------------------
# The detection chain: scheduled query rule counting SecurityIncident volume -> action group ->
# the workflow's HTTP trigger. First live composition of the monitor-action-group logic_app
# receiver.
# ------------------------------------------------------------------------------------------------

module "action_group" {
  source  = "libre-devops/monitor-action-group/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  tags              = module.tags.tags

  action_groups = {
    (local.ag_name) = {
      short_name = "alertstorm"

      logic_app_receivers = [
        {
          name         = "Run_the_alert_storm_summary_playbook"
          resource_id  = module.logic_app_workflow.ids[local.logic_name]
          callback_url = azurerm_logic_app_trigger_http_request.storm_detected.callback_url
        }
      ]
    }
  }
}

# The storm detector: incident volume over the window, threshold mirrored into the workflow's
# parameters so both sides stay in lockstep from one Terraform variable.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "alert_storm" {
  name                = "Alert_storm_-_SecurityIncident_volume_over_threshold"
  resource_group_name = module.rg.resource_group_name
  location            = local.location
  tags                = module.tags.tags

  description          = "Fires when more than ${var.storm_threshold} Sentinel incidents are created in a ${var.storm_window_minutes} minute window: an alert storm."
  severity             = 1
  enabled              = true
  scopes               = [module.law.workspace_ids[local.law_name]]
  evaluation_frequency = "PT${var.storm_window_minutes}M"
  window_duration      = "PT${var.storm_window_minutes}M"

  criteria {
    query                   = <<-KQL
      SecurityIncident
      | summarize IncidentCount = dcount(IncidentNumber)
    KQL
    time_aggregation_method = "Total"
    metric_measure_column   = null
    operator                = "GreaterThan"
    threshold               = var.storm_threshold
  }

  auto_mitigation_enabled = false

  action {
    action_groups = [module.action_group.ids[local.ag_name]]
  }

  depends_on = [module.law]
}
