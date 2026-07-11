# Plan-time tests for the module. The provider is mocked, so no credentials, no features block,
# and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  location          = "uksouth"
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01"

  workflows = {
    "logic-ldo-uks-tst-01" = {
      title = "HTTP - Page on-call when a Sentinel alert storm is detected"

      parameters = {
        storm_threshold   = { type = "Int", value = 25, description = "Alerts per window that count as a storm" }
        window_minutes    = { type = "Int", value = 5 }
        teams_webhook_url = { type = "SecureString", value = "https://example.webhook.office.com/x" }
        severity_filter   = { type = "String", value = "High", allowed_values = ["Low", "Medium", "High"] }
        scope_tags        = { type = "Object", value = "{\"env\":\"tst\",\"team\":\"sec-ops\"}" }
      }

      access_control = {
        trigger = {
          open_authentication_policies = {
            "allow-action-group" = {
              claims = { iss = "https://sts.windows.net/00000000-0000-0000-0000-000000000000/" }
            }
          }
        }
      }
    }
  }
}

# The typed parameter map generates both halves correctly, the title lands as hidden-title, and
# the identity defaults to SystemAssigned.
run "parameters_and_defaults" {
  command = plan

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].workflow_parameters["storm_threshold"]).type == "Int"
    error_message = "The parameter definition should carry the declared type."
  }

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].workflow_parameters["storm_threshold"]).metadata.description == "Alerts per window that count as a storm"
    error_message = "The parameter description should land in the definition metadata."
  }

  assert {
    condition     = azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].parameters["storm_threshold"] == "25"
    error_message = "Scalar parameter values should be stringified for the provider."
  }

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].parameters["scope_tags"]).env == "tst"
    error_message = "Object parameter values should be jsonencoded for the provider."
  }

  assert {
    condition     = length(jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].workflow_parameters["severity_filter"]).allowedValues) == 3
    error_message = "allowed_values should land in the definition."
  }

  assert {
    condition     = azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].tags["hidden-title"] == "HTTP - Page on-call when a Sentinel alert storm is detected"
    error_message = "The title should land as the hidden-title tag."
  }

  assert {
    condition     = azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].identity[0].type == "SystemAssigned"
    error_message = "The identity should default to SystemAssigned."
  }

  assert {
    condition     = tolist(tolist(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].access_control[0].trigger)[0].open_authentication_policy)[0].name == "allow-action-group"
    error_message = "Trigger open authentication policies should flow through."
  }
}

# The resource group is parsed from the id and exposed as an output.
run "parses_resource_group" {
  command = plan

  assert {
    condition     = output.resource_group_name == "rg-ldo-uks-tst-01"
    error_message = "resource_group_name should be parsed from resource_group_id."
  }
}

# Validation: an empty title is rejected (hidden-title is required by the standard).
run "rejects_empty_title" {
  command = plan

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title      = "  "
        parameters = { p = { type = "String", value = "x" } }
      }
    }
  }

  expect_failures = [var.workflows]
}

# Validation: secure parameters must not carry defaults.
run "rejects_secure_parameter_default" {
  command = plan

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title = "HTTP - test"
        parameters = {
          api_key = { type = "SecureString", value = "shh", default = "leaky" }
        }
      }
    }
  }

  expect_failures = [var.workflows]
}

# Validation: a parameter with neither value nor default is rejected.
run "rejects_valueless_parameter" {
  command = plan

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title = "HTTP - test"
        parameters = {
          dangling = { type = "String" }
        }
      }
    }
  }

  expect_failures = [var.workflows]
}

# Validation: an unknown parameter type is rejected.
run "rejects_unknown_parameter_type" {
  command = plan

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title = "HTTP - test"
        parameters = {
          p = { type = "Text", value = "x" }
        }
      }
    }
  }

  expect_failures = [var.workflows]
}

# The SAS-only exposure check warns when a workflow has no trigger access control.
run "warns_on_uncontrolled_trigger" {
  command = plan

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title      = "HTTP - test"
        parameters = { p = { type = "String", value = "x" } }
      }
    }
  }

  expect_failures = [check.trigger_access_control_is_visible]
}

# The connections map generates the full $connections parameter pair, byte-compatible with
# @parameters('$connections')['<api name>']['connectionId'] references in action bodies.
run "connections_generate_parameter" {
  command = plan

  # The fixture has no trigger access control, so the SAS-exposure check fires as designed.
  expect_failures = [check.trigger_access_control_is_visible]

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title = "Sentinel Incident - MDO incidents to ServiceNow"

        connections = {
          "azuresentinel" = {
            connection_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Web/connections/conn-sentinel-ldo-uks-tst-01"
            managed_api_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Web/locations/uksouth/managedApis/azuresentinel"
            managed_identity_auth = true
          }
          "service-now" = {
            connection_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Web/connections/conn-snow-ldo-uks-tst-01"
            connection_name = "conn-snow-ldo-uks-tst-01"
            managed_api_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Web/locations/uksouth/managedApis/service-now"
          }
        }

        diagnostics = {
          log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-01"
        }
      }
    }
  }

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].parameters["$connections"])["azuresentinel"].connectionProperties.authentication.type == "ManagedServiceIdentity"
    error_message = "managed_identity_auth should emit the ManagedServiceIdentity authentication block."
  }

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].parameters["$connections"])["service-now"].connectionName == "conn-snow-ldo-uks-tst-01"
    error_message = "connection_name should flow through (defaulting to the api key otherwise)."
  }

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].workflow_parameters["$connections"]).type == "Object"
    error_message = "The $connections definition should be generated automatically."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.this["logic-ldo-uks-tst-01"].name == "diag-logic-ldo-uks-tst-01"
    error_message = "The diagnostic setting should default to the diag-<workflow> convention name."
  }
}

# A workflow on a user assigned identity must NAME it inside every managed identity authenticated
# connection (a bare block means SystemAssigned and the platform rejects it at run time when no
# system identity exists: InvalidWorkflowManagedIdentitySpecified, caught live in azure-soc).
run "connections_identity_named_for_user_assigned" {
  command = plan

  expect_failures = [check.trigger_access_control_is_visible]

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title = "Sentinel Incident - route on a user assigned identity"

        identity = {
          type         = "UserAssigned"
          identity_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-ldo-uks-tst-01"]
        }
        connections_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-ldo-uks-tst-01"

        connections = {
          "azuresentinel" = {
            connection_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Web/connections/conn-sentinel-ldo-uks-tst-01"
            managed_api_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Web/locations/uksouth/managedApis/azuresentinel"
            managed_identity_auth = true
          }
        }
      }
    }
  }

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].parameters["$connections"])["azuresentinel"].connectionProperties.authentication.identity == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-ldo-uks-tst-01"
    error_message = "connections_identity_id should be stamped as the identity inside the ManagedServiceIdentity authentication block."
  }
}

# Validation: declaring $connections yourself while the module generates it is rejected.
run "rejects_manual_connections_parameter" {
  command = plan

  variables {
    workflows = {
      "logic-ldo-uks-tst-01" = {
        title = "HTTP - test"
        parameters = {
          "$connections" = { type = "Object", value = "{}" }
        }
      }
    }
  }

  expect_failures = [var.workflows]
}

# Shared connections land on every workflow (workflow entries win by key; opting out keeps only
# the workflow's own) and the default diagnostics workspace covers workflows without their own.
run "shared_plumbing_defaults" {
  command = plan

  expect_failures = [check.trigger_access_control_is_visible]

  variables {
    shared_connections = {
      "azuresentinel" = {
        connection_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.Web/connections/conn-sentinel-ldo-uks-tst-01"
        managed_api_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Web/locations/uksouth/managedApis/azuresentinel"
        managed_identity_auth = true
      }
    }
    diagnostics = { log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-01/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-01" }

    workflows = {
      "logic-ldo-uks-tst-01" = {
        title = "Sentinel Incident - inherits the shared plumbing"
      }
      "logic-ldo-uks-tst-02" = {
        title                  = "HTTP - opts out of everything"
        use_shared_connections = false
        diagnostics_enabled    = false
      }
    }
  }

  assert {
    condition     = jsondecode(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-01"].parameters["$connections"])["azuresentinel"].connectionProperties.authentication.type == "ManagedServiceIdentity"
    error_message = "Shared connections should land on workflows by default."
  }

  assert {
    condition     = !contains(keys(azurerm_logic_app_workflow.this["logic-ldo-uks-tst-02"].parameters), "$connections")
    error_message = "use_shared_connections = false with no own connections should mean no $connections parameter."
  }

  assert {
    condition     = contains(keys(azurerm_monitor_diagnostic_setting.this), "logic-ldo-uks-tst-01") && !contains(keys(azurerm_monitor_diagnostic_setting.this), "logic-ldo-uks-tst-02")
    error_message = "The default diagnostics workspace should cover workflow 01 and the opt-out should exclude workflow 02."
  }
}
