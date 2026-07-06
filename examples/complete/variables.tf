# Forwarded into the tags module for the DeployedBranch / DeployedRepo tags. The terraform-azure
# action fills these in CI via TF_VAR_deployed_branch / TF_VAR_deployed_repo; empty when run locally.
variable "deployed_branch" {
  description = "Git branch the deployment came from. Auto-filled in CI from TF_VAR_deployed_branch."
  type        = string
  default     = ""
}

variable "deployed_repo" {
  description = "Repository URL the deployment came from. Auto-filled in CI from TF_VAR_deployed_repo."
  type        = string
  default     = ""
}

variable "loc" {
  description = "Outfix: short Azure region code used in resource names (for example uks)."
  type        = string
  default     = "uks"
}

variable "notify_webhook_url" {
  description = "Webhook the storm summary is POSTed to. The default is a placeholder endpoint; the try/catch scope keeps the run green even when it rejects the POST."
  type        = string
  default     = "https://example.com/hooks/on-call"
}

variable "regions" {
  description = "Map of short region codes to Azure region slugs."
  type        = map(string)
  default = {
    uks = "uksouth"
    ukw = "ukwest"
    eus = "eastus"
    euw = "westeurope"
  }
}

variable "short" {
  description = "Infix: short product code used in resource names."
  type        = string
  default     = "ldo"
}

variable "storm_threshold" {
  description = "Incidents per window that count as a storm."
  type        = number
  default     = 5
}

variable "storm_window_minutes" {
  description = "Evaluation and lookback window for the storm rule, in minutes."
  type        = number
  default     = 5
}
