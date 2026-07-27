variable "newrelic_account_id" {
  description = "New Relic 管理アカウント ID（親アカウント）"
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

variable "account_name" {
  description = "作成するサブアカウント名"
  type        = string
}

variable "authentication_domain_name" {
  description = "ユーザーが所属する認証ドメイン名"
  type        = string
}

variable "group_name" {
  description = "ユーザーを追加する既存グループの名前（例: Admin）"
  type        = string
}

variable "group_user_emails" {
  description = "グループに追加するユーザーのメールアドレスリスト"
  type        = list(string)
}
