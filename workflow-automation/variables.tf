variable "newrelic_account_id" {
  description = "New Relic アカウント ID"
  type        = string
}

variable "newrelic_api_key" {
  description = "New Relic User API Key (NRAK-...)"
  type        = string
  sensitive   = true
}

variable "newrelic_region" {
  description = "New Relic リージョン (US or EU)"
  type        = string
  default     = "US"
}

variable "slack_token" {
  description = "Slack Bot Token (xoxb-...) - Secrets Manager に sre_slack_token として登録される"
  type        = string
  sensitive   = true
}

variable "app_name" {
  description = "監視対象アプリケーション名"
  type        = string
}
