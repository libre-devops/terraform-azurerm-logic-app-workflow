variable "location" {
  description = "The location for this resource to be put in"
  type        = string
}

variable "logic_app_workflows" {
  description = "The list of object settings for logic app workflows"
  type = list(object({
    name                               = string
    rg_name                            = string
    location                           = string
    tags                               = map(string)
    enabled                            = optional(bool, true)
    integration_service_environment_id = optional(string)
    logic_app_integration_account_id   = optional(string)
    identity_type                      = optional(string)
    identity_ids                       = optional(list(string))
    workflow_schema                    = optional(string)
    workflow_parameters                = optional(map(string))
    workflow_version                   = optional(string, "1.0.0.0")
    parameters                         = optional(map(string))
    access_control = optional(object({
      action = optional(object({
        allowed_caller_ip_address_range = list(string)
      }))
      content = optional(object({
        allowed_caller_ip_address_range = list(string)
      }))
      trigger = optional(object({
        allowed_caller_ip_address_range = list(string)
        open_authentication_policy = optional(object({
          name = string
          claim = optional(object({
            name  = string
            value = string
          }))
        }))
      }))
      workflow_management = optional(object({
        allowed_caller_ip_address_range = list(string)
      }))
    }))
  }))
}

variable "name" {
  type        = string
  description = "The name of the VNet gateway"
}

variable "rg_name" {
  description = "The name of the resource group, this module does not create a resource group, it is expecting the value of a resource group already exists"
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module."
}
