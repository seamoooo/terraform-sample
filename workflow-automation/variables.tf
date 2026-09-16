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
  description = "Slack Bot Token (xoxb-...) - New Relic Secrets Management に登録される"
  type        = string
  sensitive   = true
}

variable "slack_secret_namespace" {
  description = "Slack トークンを登録する Secrets Management の namespace"
  type        = string
  default     = "slack"
}

variable "slack_secret_key" {
  description = "Slack トークンを登録する Secrets Management の key"
  type        = string
  default     = "sre_slack_token"
}

variable "slack_channel" {
  description = "レポートの投稿先 Slack チャンネル名（先頭の # は不要）"
  type        = string
}

variable "app_name" {
  description = "監視対象アプリケーション名"
  type        = string
}
