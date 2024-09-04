resource "azurerm_logic_app_workflow" "workflows" {
  for_each                     = { for app in var.logic_app_workflows : app.name => app }

  location            = each.value.location
  name                = each.value.name
  resource_group_name = each.value.rg_name
  tags = each.value.tags


  dynamic "access_control" {
    for_each = ""
    content {}
  }
}
