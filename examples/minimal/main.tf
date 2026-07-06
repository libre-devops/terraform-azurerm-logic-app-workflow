locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  logic_name = "logic-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

# Minimal call: one workflow shell with a typed parameter. Content (a trigger and an action) is
# authored as raw resources against the module's id, per the Libre DevOps Logic App standard.
module "logic_app_workflow" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  workflows = {
    (local.logic_name) = {
      title = "Scheduled - Prove the workflow shell applies and runs"

      parameters = {
        greeting = { type = "String", value = "hello from the module", description = "Demonstrates @parameters() referencing" }
      }

      # The recurrence trigger needs no inbound access; restrict management-plane callback fetches
      # anyway so the check stays honest.
      access_control = {
        trigger = { allowed_ips = ["0.0.0.0/0"] }
      }
    }
  }
}

# Content: the standard's shape. The trigger is the root (never depends_on); the action chains
# from it explicitly.
resource "azurerm_logic_app_trigger_recurrence" "daily" {
  name         = "Recurrence_-_Once_a_day_at_08_00_UTC"
  logic_app_id = module.logic_app_workflow.ids[local.logic_name]

  frequency  = "Day"
  interval   = 1
  start_time = "2026-01-01T08:00:00Z"
  time_zone  = "UTC"
}

resource "azurerm_logic_app_action_custom" "compose_greeting" {
  name         = "Compose_-_Render_the_parameterised_greeting"
  logic_app_id = module.logic_app_workflow.ids[local.logic_name]

  body = jsonencode({
    description = "Composes the greeting from the workflow parameter, proving @parameters() flows end to end."
    type        = "Compose"
    inputs      = "@parameters('greeting')"
    runAfter    = {}
  })

  depends_on = [azurerm_logic_app_trigger_recurrence.daily]
}
