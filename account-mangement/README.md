# New Relic Account Management

New Relic のサブアカウントを作成し、既存グループに既存ユーザーを追加する Terraform 構成。

## 構成内容

1. `newrelic_account_management` — サブアカウントの作成
2. `data "external"` — グループ名から NerdGraph API でグループ ID を自動取得
3. `terraform_data` + NerdGraph API — 既存グループへのユーザー追加（既存メンバーに影響なし）

## なぜ `newrelic_group` リソースを使わないのか

`newrelic_group` は `user_ids` でグループメンバーを**宣言的に管理**します。
つまり、指定していないユーザーはグループから削除されます。
既存グループに「追加だけ」したい場合には適しません。

代わりに NerdGraph の `userManagementAddUsersToGroups` ミューテーションを直接呼ぶことで、
既存メンバーを壊さずにユーザーを追加します。

## 前提条件

- Terraform >= 1.3
- `curl` / `jq` コマンド
- New Relic User API Key（`NRAK-...` 形式、Organization レベルの権限が必要）
- 追加するユーザーが既に New Relic に登録済みであること

## 使い方

```bash
# 初期化
terraform init

# tfvars ファイルを作成
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集して実際の値を設定

# プラン確認
terraform plan

# 適用
terraform apply
```

## 変数

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `newrelic_account_id` | 管理アカウント ID（親アカウント） | - |
| `newrelic_api_key` | User API Key | - |
| `newrelic_region` | リージョン | `US` |
| `account_name` | 作成するサブアカウント名 | - |
| `authentication_domain_name` | ユーザーの認証ドメイン名 | - |
| `group_name` | ユーザーを追加する既存グループの名前 | - |
| `group_user_emails` | グループに追加するユーザーのメールアドレス | - |

## 出力

| 出力名 | 説明 |
|--------|------|
| `account_id` | 作成されたサブアカウントの ID |
| `group_id` | ユーザーを追加したグループの ID |
| `added_user_ids` | グループに追加されたユーザー ID |
