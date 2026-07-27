#!/bin/bash
# =============================================================================
# NerdGraph API でグループ名からグループ ID を取得する
# Terraform external data source 用スクリプト
# =============================================================================

set -e

# stdin から JSON 入力を読み取る（Terraform external data source の仕様）
eval "$(jq -r '@sh "API_KEY=\(.api_key) AUTH_DOMAIN_ID=\(.authentication_domain_id) GROUP_NAME=\(.group_name)"')"

# NerdGraph クエリ
QUERY='{
  "query": "{ actor { organization { userManagement { authenticationDomains(id: [\"'$AUTH_DOMAIN_ID'\"]) { authenticationDomains { groups { groups { id displayName } } } } } } } }"
}'

# API 呼び出し
RESPONSE=$(curl -s -X POST https://api.newrelic.com/graphql \
  -H "Content-Type: application/json" \
  -H "API-Key: ${API_KEY}" \
  -d "$QUERY")

# グループ名でフィルタして ID を取得
GROUP_ID=$(echo "$RESPONSE" | jq -r --arg name "$GROUP_NAME" '
  .data.actor.organization.userManagement.authenticationDomains.authenticationDomains[0].groups.groups[]
  | select(.displayName == $name)
  | .id
')

if [ -z "$GROUP_ID" ] || [ "$GROUP_ID" = "null" ]; then
  echo "Error: Group '${GROUP_NAME}' not found" >&2
  exit 1
fi

# Terraform external data source 形式で出力
jq -n --arg group_id "$GROUP_ID" '{"group_id": $group_id}'
