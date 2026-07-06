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
- **Diagnostics declared once**: `diagnostics` gives every workflow an
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
  diagnostics = { log_analytics_workspace_id = module.law.workspace_ids["log-ldo-uks-prd-001"] }

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
