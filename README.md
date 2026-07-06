<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Logic App Workflow

Consumption Logic App workflow shells with typed parameters, shared API connections, access
control, and the hidden-title tag, per the Libre DevOps Logic App standard.

[![CI](https://github.com/libre-devops/terraform-azurerm-logic-app-workflow/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-logic-app-workflow/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-logic-app-workflow?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-logic-app-workflow/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-logic-app-workflow)](./LICENSE)

---

## Overview

The module owns the workflow SHELL; content (triggers and actions) is authored as raw
`azurerm_logic_app_trigger_*` / `azurerm_logic_app_action_*` resources against the module's ids,
per the [Libre DevOps Logic App standard](https://libredevops.org/docs/documents/azure-logic-app-standards/):
content graphs are per-playbook and separate resources give explicit `depends_on` ordering.

What the shell earns:

- **Typed parameters, the no-hardcoding path**: one entry generates both the workflow parameter
  definition (type, defaultValue, allowedValues, description) and its deployment value; content
  only ever says `@parameters('name')`. Secure types cannot carry defaults or allowed values
  (definitions are Reader-visible), every parameter must have a value or default, and values are
  type-checked at plan time.
- **Connections declared once**: `shared_connections` puts the estate's common API connections
  (the usual Sentinel/Monitor/ITSM set) on every workflow; per-workflow `connections` merge over
  them by key, and `use_shared_connections = false` opts out. The module generates the entire
  `$connections` parameter pair, including the `ManagedServiceIdentity` authentication block, byte
  compatible with `@parameters('$connections')['<api>']['connectionId']` references.
- **Diagnostics declared once**: `diagnostics_log_analytics_workspace_id` gives every workflow an
  allLogs diagnostic setting named `diag-<workflow>`, with per-workflow override and opt-out.
- **The hidden-title tag is required**: `title` becomes the portal subtitle, as the standard
  mandates.
- **Access control first-class**: per-plane IP restrictions and AAD open authentication policies
  on the trigger; a `check` flags workflows whose triggers are SAS-only.

The retired Integration Service Environment is deliberately not exposed. The resource group is
passed by id and parsed.

## Usage

```hcl
locals {
  # The playbook catalog: one entry per workflow shell; content lives in per-playbook files.
  playbooks = {
    "logic-ldo-uks-prd-001" = {
      title = "Sentinel Incident - MDO incidents to ServiceNow"
    }
    "logic-ldo-uks-prd-002" = {
      title = "HTTP - Summarise a Sentinel alert storm and notify on-call"
      parameters = {
        storm_threshold = { type = "Int", value = var.storm_threshold }
      }
    }
  }
}

module "playbooks" {
  source  = "libre-devops/logic-app-workflow/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids["rg-ldo-uks-prd-001"]
  location          = "uksouth"
  tags              = module.tags.tags

  shared_connections = {
    "azuresentinel" = {
      connection_id         = azapi_resource.sentinel_connection.id
      managed_api_id        = data.azurerm_managed_api.sentinel.id
      managed_identity_auth = true
    }
  }
  diagnostics_log_analytics_workspace_id = module.law.workspace_ids["log-ldo-uks-prd-001"]

  workflows = local.playbooks
}
```

## Examples

- [`examples/minimal`](./examples/minimal) - one shell plus the standard's content shape: a
  recurrence trigger and a Compose action proving `@parameters()` end to end.
- [`examples/complete`](./examples/complete) - the alert-storm playbook: a Sentinel-onboarded
  workspace, our own Sentinel API connection (azapi, managed identity auth) as the shared estate
  default, a scheduled query rule counting incident volume, an action group whose logic app
  receiver fires the workflow's HTTP trigger, and content with verbose names, descriptions on
  every action, an explicit exponential retry policy, and a Scope try/catch.

## Developing

Local work needs **PowerShell 7+** and **[`just`](https://github.com/casey/just)**, because the recipes
wrap the [LibreDevOpsHelpers](https://www.powershellgallery.com/packages/LibreDevOpsHelpers)
PowerShell module (the same engine the `libre-devops/terraform-azure` action runs in CI). Install
just with `brew install just`, or `uv tool add rust-just` then `uv run just <recipe>`.

Run `just` to list recipes: `just update-ldo-pwsh` (install or force-update LibreDevOpsHelpers from
PSGallery), `just validate`, `just scan` (Trivy only), `just pwsh-analyze` (PSScriptAnalyzer only),
`just plan`, `just apply`, `just destroy`, `just e2e`, `just test`, and `just docs` (the
plan/apply/destroy recipes mirror the action, including the storage firewall dance; `just e2e`
applies an example then always destroys it, defaulting to `minimal`, so nothing is left running).
Releasing is also `just`:
`just increment-release [patch|minor|major]` bumps, tags, and publishes a GitHub release, and the
Terraform Registry picks up the tag.

## Security scan exceptions

This module is scanned with [Trivy](https://github.com/aquasecurity/trivy); HIGH and CRITICAL
findings fail the build. Any waiver is a deliberate, reviewed decision, never a way to quiet a
finding that should be fixed. Waivers live in [`.trivyignore.yaml`](./.trivyignore.yaml) (the
machine-applied source of truth, passed to Trivy with `--ignorefile`) and are mirrored in the table
below so the reason is auditable.

| Trivy ID | Resource | Finding | Justification |
|----------|----------|---------|---------------|
| _None_   |          |         |               |

To add an exception: add an entry to `.trivyignore.yaml` (`id`, optional `paths` to scope it, and a
`statement` recording why), then add a matching row here. Where the finding is out of this module's
scope, point the justification at the Libre DevOps module that does address it (for example the
private-endpoint module). Both the file and this table are reviewed in the pull request.

## Reference

The Requirements, Providers, Inputs, Outputs, and Resources below are generated by `terraform-docs`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_logic_app_workflow.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_workflow) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_diagnostics_log_analytics_workspace_id"></a> [diagnostics\_log\_analytics\_workspace\_id](#input\_diagnostics\_log\_analytics\_workspace\_id) | When set, every workflow gets an allLogs diagnostic setting to this workspace (named diag-<workflow>) unless it sets its own diagnostics or opts out with diagnostics\_enabled = false. | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the workflows. | `string` | n/a | yes |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Resource id of the resource group the workflows are created in. The resource group name and subscription are parsed from this id. | `string` | n/a | yes |
| <a name="input_shared_connections"></a> [shared\_connections](#input\_shared\_connections) | API connections shared by every workflow in the call (the usual estate shape: the same Sentinel/Monitor/ITSM connections on every playbook), keyed by managed API name. Merged under each workflow's own connections (same-key workflow entries win); a workflow opts out with use\_shared\_connections = false. | <pre>map(object({<br/>    connection_id         = string<br/>    connection_name       = optional(string)<br/>    managed_api_id        = string<br/>    managed_identity_auth = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the workflows (merged with per-workflow tags; the workflow's title always lands as the hidden-title tag). | `map(string)` | `{}` | no |
| <a name="input_workflows"></a> [workflows](#input\_workflows) | Consumption Logic App workflows (Microsoft.Logic/workflows) keyed by name<br/>(logic-ldo-uks-prd-001). The workflow content (triggers and actions) is authored as raw<br/>azurerm\_logic\_app\_trigger\_* / azurerm\_logic\_app\_action\_* resources per the Libre DevOps Logic<br/>App standard; this module owns the shell. Fields:<br/>  title       REQUIRED human-readable description, becomes the hidden-title tag the portal<br/>              renders as the resource subtitle ("{Trigger type} - {what it does}").<br/>  parameters  Typed workflow parameters, the no-hardcoding path. Each entry generates BOTH the<br/>              workflow parameter definition (type, defaultValue, description, allowedValues)<br/>              AND its deployment value, so content only ever references<br/>              @parameters('name'). Types: String, SecureString, Int, Float, Bool, Object,<br/>              Array, SecureObject. Values are strings (Terraform coerces numbers and bools, so<br/>              value = 25 works; Object and Array values pass jsonencode(...), the same rule<br/>              the standard sets for all workflow JSON); the module converts defaults and<br/>              allowed values back to their real JSON types in the definition. Secure types<br/>              must not set default or allowed\_values (their definitions are readable by anyone<br/>              with Reader).<br/>  identity    SystemAssigned by default; UserAssigned supported.<br/>  connections API connections for the workflow's managed connectors, keyed by the managed API<br/>              name the action bodies reference. Generates the entire $connections parameter<br/>              pair (definition and value: connectionId, connectionName, id, and the<br/>              ManagedServiceIdentity authentication block when managed\_identity\_auth is true),<br/>              so bodies keep saying<br/>              @parameters('$connections')['<api name>']['connectionId'] with zero hand-rolled<br/>              JSON.<br/>  diagnostics Optional per-workflow diagnostic setting (allLogs) to a Log Analytics workspace,<br/>              named diag-<workflow> unless overridden.<br/>  access\_control  IP restrictions for action/content/workflow\_management, and for the trigger<br/>              additionally AAD open authentication policies (claims like iss/aud/appid), the<br/>              right way to let an action group or app call an HTTP trigger without shared<br/>              SAS exposure.<br/>  enabled, workflow\_schema, workflow\_version, integration\_account\_id  Pass-throughs.<br/>The retired Integration Service Environment (integration\_service\_environment\_id) is<br/>deliberately not exposed. | <pre>map(object({<br/>    title   = string<br/>    enabled = optional(bool, true)<br/>    tags    = optional(map(string))<br/><br/>    identity = optional(object({<br/>      type         = optional(string, "SystemAssigned")<br/>      identity_ids = optional(set(string))<br/>    }), {})<br/><br/>    parameters = optional(map(object({<br/>      type           = string<br/>      value          = optional(string)<br/>      default        = optional(string)<br/>      description    = optional(string)<br/>      allowed_values = optional(list(string))<br/>    })), {})<br/><br/>    connections = optional(map(object({<br/>      connection_id         = string<br/>      connection_name       = optional(string)<br/>      managed_api_id        = string<br/>      managed_identity_auth = optional(bool, false)<br/>    })), {})<br/>    use_shared_connections = optional(bool, true)<br/><br/>    diagnostics = optional(object({<br/>      log_analytics_workspace_id = string<br/>      name                       = optional(string)<br/>    }))<br/>    diagnostics_enabled = optional(bool, true)<br/><br/>    access_control = optional(object({<br/>      action_allowed_ips              = optional(list(string))<br/>      content_allowed_ips             = optional(list(string))<br/>      workflow_management_allowed_ips = optional(list(string))<br/>      trigger = optional(object({<br/>        allowed_ips = optional(list(string), [])<br/>        open_authentication_policies = optional(map(object({<br/>          claims = map(string)<br/>        })), {})<br/>      }))<br/>    }))<br/><br/>    workflow_schema        = optional(string)<br/>    workflow_version       = optional(string)<br/>    integration_account_id = optional(string)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_endpoints"></a> [access\_endpoints](#output\_access\_endpoints) | Map of workflow name to its access endpoint. |
| <a name="output_connector_outbound_ip_addresses"></a> [connector\_outbound\_ip\_addresses](#output\_connector\_outbound\_ip\_addresses) | Map of workflow name to the outbound IPs its managed connectors call from (for allow-listing on downstream firewalls). |
| <a name="output_identities"></a> [identities](#output\_identities) | Map of workflow name to its identity { principal\_id, tenant\_id } (principal\_id is populated for system-assigned identities), for role assignments. |
| <a name="output_ids"></a> [ids](#output\_ids) | Map of workflow name to its resource id. |
| <a name="output_ids_zipmap"></a> [ids\_zipmap](#output\_ids\_zipmap) | Map of workflow name to a { name, id } object, for passing where both are needed together. |
| <a name="output_names"></a> [names](#output\_names) | The workflow names. |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group name parsed from resource\_group\_id. |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Subscription id parsed from resource\_group\_id. |
| <a name="output_tags"></a> [tags](#output\_tags) | The base tags applied to the workflows. |
| <a name="output_workflow_outbound_ip_addresses"></a> [workflow\_outbound\_ip\_addresses](#output\_workflow\_outbound\_ip\_addresses) | Map of workflow name to the outbound IPs the workflow runtime calls from (for allow-listing on downstream firewalls). |
<!-- END_TF_DOCS -->
