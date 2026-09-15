# New Relic Workflow Automation - SRE Agent Report

アラート発生時に New Relic SRE Agent を自動実行し、原因分析レポートを Slack チャンネルに投稿する Terraform コードです。

## アーキテクチャ

```
Alert Condition (エラーレート超過)
  → Alert Policy
    → Alert Workflow (newrelic_workflow)
      → Notification Channel (WORKFLOW_AUTOMATION)
        → Workflow Automation (sre-agent-report-to-slack)
          Step 1: ログ出力（受信パラメータの記録）
          Step 2: SRE Agent 実行（原因調査 & レポート作成）
          Step 3: Slack にレポート投稿
```

## 作成されるリソース

| リソース | 名前 | 説明 |
|---------|------|------|
| `newrelic_workflow_automation` | `sre-agent-report-to-slack` | SRE Agent を実行して Slack 通知するワークフロー |
| `newrelic_alert_policy` | `{app_name} - SRE Agent Alert Policy` | アラートポリシー |
| `newrelic_nrql_alert_condition` | `{app_name} - High Error Rate` | エラーレート監視条件 |
| `newrelic_notification_channel` | `{app_name} - SRE Agent Report Channel` | Workflow Automation 通知チャンネル |
| `newrelic_workflow` | `sre-agent-to-slack` | アラート → Workflow Automation トリガー |
| `terraform_data` | Secret 登録 / Destination ID 取得 | NerdGraph API 経由の補助リソース |

## ファイル構成

```
workflow-automation/
├── main.tf                                    # メインリソース定義
├── variables.tf                               # 入力変数
├── outputs.tf                                 # 出力値
├── versions.tf                                # Provider バージョン制約
├── terraform.tfvars.example                   # 変数ファイルサンプル
├── .gitignore
├── scripts/
│   └── get-or-create-destination.sh           # Destination ID 取得スクリプト（冪等）
└── definitions/
    └── sre-agent-report.yaml                  # Workflow Automation YAML 定義
```

## 前提条件

- Terraform >= 1.3
- New Relic Terraform Provider ~> 3.93
- New Relic アカウント + User API Key (`NRAK-...`)
- Slack Bot Token (`xoxb-...`)
- **WORKFLOW_AUTOMATION タイプの Destination が New Relic コンソールで作成済みであること**
  - Alerts > Destinations > Workflow Automation から作成

## セットアップ

### 1. Destination の作成（初回のみ・手動）

WORKFLOW_AUTOMATION タイプの Destination は API からは作成できないため、New Relic コンソールで作成してください。

1. [one.newrelic.com](https://one.newrelic.com) > All capabilities > Alerts > Destinations
2. 「Workflow Automation」タイルをクリック
3. 名前と API Key を入力して「Save destination」

### 2. 変数ファイルの準備

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` を編集:

```hcl
newrelic_account_id = "YOUR_ACCOUNT_ID"
newrelic_api_key    = "NRAK-XXXXXXXXXXXXXXXXXXXXXXXXX"
newrelic_region     = "US"
slack_token         = "xoxb-XXXXXXXXXXXXXXXXXXXXXXXXX"
app_name            = "my-application"
```

### 3. 適用

```bash
terraform init
terraform plan
terraform apply
```

## Workflow Automation の動作

### アラートから渡されるパラメータ

| パラメータ | ソース | 型 | 説明 |
|-----------|--------|-----|------|
| `account_id` | `{{ nrAccountId }}` | Int | New Relic アカウント ID |
| `IssueId` | `{{ issueId }}` | String | アラート Issue ID |
| `entityGuid` | `{{#each entitiesData.ids}}{{this}}{{#unless @last}}, {{/unless}}{{/each}}` | String | 影響を受けたエンティティ GUID（カンマ区切り） |

### ワークフローステップ

1. **newrelic_agent_run** - SRE Agent にパラメータを渡して原因調査を実行
2. **slack_chat_postMessage_4** - SRE Agent のレポートを Slack チャンネル `#perfect-cat-streaming` に投稿

### Secrets

Slack Token は New Relic Secrets Manager に `sre_slack_token` として格納され、YAML 内で `${{ :secrets:slack:sre_slack_token }}` として参照されます。

## デバッグ

アラートから渡されたパラメータを確認するには:

```sql
SELECT * FROM Log WHERE logtype = 'workflow-automation-debug' SINCE 1 hour ago
```

Workflow Automation の実行履歴は:
- one.newrelic.com > All Capabilities > Workflow Automation > `sre-agent-report-to-slack` > Run history

## 注意事項

- `newrelic_workflow_automation` の `name` と YAML 定義内の `name` は一致させる必要がある
- `WORKFLOW_AUTOMATION` Destination は Terraform/API では作成できない（UI 操作が必要）
- `scripts/get-or-create-destination.sh` は既存の Destination を自動検索するため冪等に動作する
- `definition` を更新すると Workflow Automation の `version` が自動インクリメントされる
