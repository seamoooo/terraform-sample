# =============================================================================
# New Relic Workflow Automation - SRE Agent Report
# =============================================================================
# アラート発生時に SRE Agent を実行し、分析レポートを Slack に送信する
# =============================================================================

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key
  region     = var.newrelic_region
}

# -----------------------------------------------------------------------------
# Secret: sre_slack_token
# -----------------------------------------------------------------------------
# New Relic Secrets Management にトークンを登録する。
# 既に同じ namespace / key が存在する場合はスクリプト側で更新する。
# 値は環境変数でスクリプトに渡す（コマンドライン引数は ps などから見えるため）。
resource "terraform_data" "sre_slack_token_secret" {
  # トークン・namespace・key のいずれかが変わったら再登録する
  triggers_replace = [
    var.slack_token,
    var.slack_secret_namespace,
    var.slack_secret_key,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/register-secret.sh"

    environment = {
      NR_ACCOUNT_ID      = var.newrelic_account_id
      NR_API_KEY         = var.newrelic_api_key
      NR_REGION          = var.newrelic_region
      SECRET_NAMESPACE   = var.slack_secret_namespace
      SECRET_KEY         = var.slack_secret_key
      SECRET_VALUE       = var.slack_token
      SECRET_DESCRIPTION = "Slack token for SRE agent report workflow"
    }
  }
}

# -----------------------------------------------------------------------------
# Workflow Automation: SRE Agent Report
# -----------------------------------------------------------------------------
resource "newrelic_workflow_automation" "sre_agent_report" {
  name       = "sre-agent-report-to-slack"
  scope_id   = var.newrelic_account_id
  scope_type = "ACCOUNT"

  # YAML 内のプレースホルダを変数の値に差し替える
  # （YAML に含まれる ${{ }} が Terraform の補間と衝突するため templatefile は使わない）
  definition = replace(
    replace(
      replace(
        file("${path.module}/definitions/sre-agent-report.yaml"),
        "__SLACK_CHANNEL__", var.slack_channel
      ),
      "__SECRET_NAMESPACE__", var.slack_secret_namespace
    ),
    "__SECRET_KEY__", var.slack_secret_key
  )

  depends_on = [terraform_data.sre_slack_token_secret]
}

# =============================================================================
# Alert Workflow → Workflow Automation 連携
# =============================================================================
# アラート発生時に上記の Workflow Automation を自動トリガーする設定

# -----------------------------------------------------------------------------
# Alert Policy
# -----------------------------------------------------------------------------
resource "newrelic_alert_policy" "sre_alert_policy" {
  name                = "${var.app_name} - SRE Agent Alert Policy"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

# -----------------------------------------------------------------------------
# NRQL Alert Condition (例: エラーレート監視)
# -----------------------------------------------------------------------------
resource "newrelic_nrql_alert_condition" "error_rate" {
  account_id = var.newrelic_account_id
  policy_id  = newrelic_alert_policy.sre_alert_policy.id
  type       = "static"
  name       = "${var.app_name} - High Error Rate"
  enabled    = true

  nrql {
    query = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '${var.app_name}'"
  }

  critical {
    operator              = "above"
    threshold             = 5
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "above"
    threshold             = 2
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  fill_option                        = "none"
  aggregation_window                 = 60
  aggregation_method                 = "event_flow"
  aggregation_delay                  = 120
  expiration_duration                = 600
  open_violation_on_expiration       = false
  close_violations_on_expiration     = true
}

# -----------------------------------------------------------------------------
# Notification Destination: Workflow Automation
# -----------------------------------------------------------------------------
# WORKFLOW_AUTOMATION タイプの Destination は Terraform リソースでは作成エラーになるため、
# NerdGraph API 経由で検索/作成し、ID を取得する（冪等）
resource "terraform_data" "workflow_automation_destination" {
  input = var.newrelic_account_id

  provisioner "local-exec" {
    command = "${path.module}/scripts/get-or-create-destination.sh ${var.newrelic_account_id} ${var.newrelic_api_key} ${path.module}/destination_response.json"
  }
}

data "local_file" "destination_response" {
  filename   = "${path.module}/destination_response.json"
  depends_on = [terraform_data.workflow_automation_destination]
}

locals {
  destination_id = jsondecode(data.local_file.destination_response.content).destination_id
}

# -----------------------------------------------------------------------------
# Notification Channel: Workflow Automation
# -----------------------------------------------------------------------------
resource "newrelic_notification_channel" "workflow_automation" {
  account_id     = var.newrelic_account_id
  name           = "${var.app_name} - SRE Agent Report Channel"
  type           = "WORKFLOW_AUTOMATION"
  destination_id = local.destination_id
  product        = "IINT"

  property {
    key   = "account_id"
    value = "{{ nrAccountId }}"
    label = "Account_id"
  }

  property {
    key   = "IssueId"
    value = "{{ issueId }}"
    label = "IssueId"
  }

  property {
    key   = "entityGuid"
    value = "{{#each entitiesData.ids}}{{this}}{{#unless @last}}, {{/unless}}{{/each}}"
    label = "EntityGuid"
  }

  property {
    key           = "workflowAutomation"
    value         = newrelic_workflow_automation.sre_agent_report.name
    label         = "Workflow Automation Name"
    display_value = newrelic_workflow_automation.sre_agent_report.name
  }

  property {
    key   = "workflowAutomationVersion"
    value = "1"
    label = "Select Version"
  }
}

# -----------------------------------------------------------------------------
# Alert Workflow: Workflow Automation をトリガーする
# -----------------------------------------------------------------------------
resource "newrelic_workflow" "trigger_sre_agent" {
  account_id            = var.newrelic_account_id
  name                  = "sre-agent-to-slack"
  enabled               = true
  muting_rules_handling = "DONT_NOTIFY_FULLY_MUTED_ISSUES"

  issues_filter {
    name = "workflow_filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.sre_alert_policy.id]
    }
  }

  destination {
    channel_id             = newrelic_notification_channel.workflow_automation.id
    notification_triggers  = ["ACKNOWLEDGED", "ACTIVATED", "CLOSED", "INVESTIGATING", "OTHER_UPDATES", "PRIORITY_CHANGED"]
    update_original_message = true
  }
}
