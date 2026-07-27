output "account_id" {
  description = "作成されたサブアカウントの ID"
  value       = newrelic_account_management.this.id
}

output "group_id" {
  description = "ユーザーを追加したグループの ID"
  value       = data.external.group.result.group_id
}

output "added_user_ids" {
  description = "グループに追加されたユーザー ID"
  value       = [for user in data.newrelic_user.members : user.id]
}
