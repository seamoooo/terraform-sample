# =============================================================================
# New Relic Account Management
# =============================================================================
# サブアカウントを作成し、既存グループに既存ユーザーを追加する
# =============================================================================

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key
  region     = var.newrelic_region
}

# -----------------------------------------------------------------------------
# サブアカウントの作成
# -----------------------------------------------------------------------------
resource "newrelic_account_management" "this" {
  name = var.account_name
}

# -----------------------------------------------------------------------------
# 認証ドメインの参照
# -----------------------------------------------------------------------------
data "newrelic_authentication_domain" "this" {
  name = var.authentication_domain_name
}

# -----------------------------------------------------------------------------
# 既存ユーザーの参照（メールアドレスで検索）
# -----------------------------------------------------------------------------
data "newrelic_user" "members" {
  for_each = toset(var.group_user_emails)

  authentication_domain_id = data.newrelic_authentication_domain.this.id
  email_id                 = each.value
}

# -----------------------------------------------------------------------------
# グループ名からグループ ID を取得
# -----------------------------------------------------------------------------
data "external" "group" {
  program = ["bash", "${path.module}/scripts/get-group-id.sh"]

  query = {
    api_key                  = var.newrelic_api_key
    authentication_domain_id = data.newrelic_authentication_domain.this.id
    group_name               = var.group_name
  }
}

# -----------------------------------------------------------------------------
# 既存グループにユーザーを追加
# -----------------------------------------------------------------------------
# NerdGraph の userManagementAddUsersToGroups ミューテーションを使用
# triggers_replace で毎回実行を保証する
# -----------------------------------------------------------------------------
resource "terraform_data" "add_users_to_group" {
  triggers_replace = {
    group_id  = data.external.group.result.group_id
    user_ids  = join(",", [for user in data.newrelic_user.members : user.id])
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/add-users-to-group.sh ${var.newrelic_api_key} ${data.external.group.result.group_id} ${join(" ", [for user in data.newrelic_user.members : user.id])}"
  }
}
