#!/bin/bash
# =============================================================================
# NerdGraph API で既存グループにユーザーを追加する
# 使用法: ./add-users-to-group.sh <api_key> <group_id> <user_id1> [user_id2] ...
# =============================================================================

set -euo pipefail

API_KEY="$1"
GROUP_ID="$2"
shift 2

# ユーザー ID を JSON 配列に変換（jq で安全にエスケープ）
USER_IDS_JSON=$(printf '%s\n' "$@" | jq -R . | jq -s .)

if [ "$USER_IDS_JSON" = "[]" ]; then
  echo "Error: No user IDs provided" >&2
  exit 1
fi

# GraphQL mutation を jq で安全に組み立てる
MUTATION="mutation { userManagementAddUsersToGroups(addUsersToGroupsOptions: {groupIds: [\"${GROUP_ID}\"], userIds: PLACEHOLDER}) { groups { id displayName } } }"
# PLACEHOLDER を実際の配列で置換
MUTATION=$(echo "$MUTATION" | sed "s/PLACEHOLDER/$(echo "$USER_IDS_JSON" | jq -c .)/")

QUERY=$(jq -n --arg query "$MUTATION" '{"query": $query}')

echo "Adding users to group ${GROUP_ID}..."
echo "User IDs: ${USER_IDS_JSON}"
echo "Request body: ${QUERY}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST https://api.newrelic.com/graphql \
  -H "Content-Type: application/json" \
  -H "API-Key: ${API_KEY}" \
  -d "$QUERY")

# レスポンスと HTTP ステータスコードを分離
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "HTTP Status: ${HTTP_CODE}"
echo "Response: ${BODY}"

# エラーチェック
if [ "$HTTP_CODE" -ne 200 ]; then
  echo "Error: API returned HTTP ${HTTP_CODE}" >&2
  exit 1
fi

# GraphQL エラーチェック
ERRORS=$(echo "$BODY" | jq -r '.errors // empty')
if [ -n "$ERRORS" ]; then
  echo "Error: GraphQL errors detected:" >&2
  echo "$ERRORS" | jq . >&2
  exit 1
fi

echo "Successfully added users to group."
