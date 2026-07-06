# Post-plan sanity checks: informational (warn), they never fail an apply.

check "has_workflows" {
  assert {
    condition     = length(var.workflows) > 0
    error_message = "No workflows are defined: the module call creates nothing."
  }
}

# An HTTP-triggered workflow with neither IP restrictions nor AAD open authentication on the
# trigger accepts calls from anyone holding the SAS URL. Legal, and right for some integrations,
# but worth seeing.
check "trigger_access_control_is_visible" {
  assert {
    # try() guards the null side: 1.9 evaluates both || operands.
    condition = alltrue([
      for w in values(var.workflows) :
      length(try(w.access_control.trigger.allowed_ips, [])) > 0 || length(try(w.access_control.trigger.open_authentication_policies, {})) > 0
    ])
    error_message = "At least one workflow has no trigger access control (IP allow-list or AAD open authentication): its triggers are callable by anyone with the SAS URL."
  }
}
