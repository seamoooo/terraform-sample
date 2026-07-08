output "sre_agent_report_id" {
  description = "SRE Agent Report ワークフローの Definition ID"
  value       = newrelic_workflow_automation.sre_agent_report.definition_id
}

output "sre_agent_report_version" {
  description = "SRE Agent Report ワークフローの現在のバージョン"
  value       = newrelic_workflow_automation.sre_agent_report.version
}

output "alert_policy_id" {
  description = "Alert Policy ID"
  value       = newrelic_alert_policy.sre_alert_policy.id
}

output "alert_workflow_id" {
  description = "Alert Workflow ID (Workflow Automation をトリガーする)"
  value       = newrelic_workflow.trigger_sre_agent.id
}

output "workflow_automation_destination_id" {
  description = "Workflow Automation Notification Destination ID"
  value       = local.destination_id
}
