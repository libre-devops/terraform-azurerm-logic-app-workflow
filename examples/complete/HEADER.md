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
