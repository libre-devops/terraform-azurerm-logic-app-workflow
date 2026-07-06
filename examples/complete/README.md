<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The alert-storm playbook, end to end: a Sentinel-onboarded workspace (purge with delete --force on
teardown), our own Sentinel API connection (azapi, parameterValueType Alternative, access policy
for the workflow identity) as the single shared estate connection, typed parameters
(threshold/webhook/retries, zero hardcoded values), a scheduled query rule counting
SecurityIncident volume, an action group whose logic app receiver fires the workflow's HTTP
trigger with the common alert schema, and content meeting the playbook quality bar: verbose names,
a description on every action, an explicit exponential retryPolicy on the notification POST, and
a Scope try/catch whose catch path keeps the run green while recording the failure. The
environment comes from the Terraform workspace (`terraform.workspace`), not a variable. Run it
with `just e2e complete`, which applies the stack then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | >= 2.0.0, < 3.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | 2.10.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.80.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_action_group"></a> [action\_group](#module\_action\_group) | libre-devops/monitor-action-group/azurerm | ~> 4.0 |
| <a name="module_law"></a> [law](#module\_law) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_logic_app_workflow"></a> [logic\_app\_workflow](#module\_logic\_app\_workflow) | ../../ | n/a |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [azapi_resource.sentinel_connection](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.sentinel_connection_access](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azurerm_logic_app_action_custom.catch_record_notification_failure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_action_custom) | resource |
| [azurerm_logic_app_action_custom.compose_storm_summary](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_action_custom) | resource |
| [azurerm_logic_app_action_custom.try_notify_oncall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_action_custom) | resource |
| [azurerm_logic_app_trigger_http_request.storm_detected](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_trigger_http_request) | resource |
| [azurerm_monitor_scheduled_query_rules_alert_v2.alert_storm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_scheduled_query_rules_alert_v2) | resource |
| [azurerm_managed_api.sentinel](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/managed_api) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_notify_webhook_url"></a> [notify\_webhook\_url](#input\_notify\_webhook\_url) | Webhook the storm summary is POSTed to. The default is a placeholder endpoint; the try/catch scope keeps the run green even when it rejects the POST. | `string` | `"https://example.com/hooks/on-call"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |
| <a name="input_storm_threshold"></a> [storm\_threshold](#input\_storm\_threshold) | Incidents per window that count as a storm. | `number` | `5` | no |
| <a name="input_storm_window_minutes"></a> [storm\_window\_minutes](#input\_storm\_window\_minutes) | Evaluation and lookback window for the storm rule, in minutes. | `number` | `5` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_action_group_ids"></a> [action\_group\_ids](#output\_action\_group\_ids) | The action group the storm rule notifies. |
| <a name="output_storm_rule_id"></a> [storm\_rule\_id](#output\_storm\_rule\_id) | The scheduled query rule detecting the storm. |
| <a name="output_workflow_ids"></a> [workflow\_ids](#output\_workflow\_ids) | Map of workflow name to resource id. |
<!-- END_TF_DOCS -->
