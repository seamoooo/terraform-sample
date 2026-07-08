#!/bin/bash
# =============================================================================
# get-or-create-destination.sh
# =============================================================================
# WORKFLOW_AUTOMATION タイプの Destination を NerdGraph API で検索する。
# 見つからない場合はエラーとして案内を表示する。
#
# ※ WORKFLOW_AUTOMATION タイプの Destination は API/Terraform では作成不可のため、
#    事前に New Relic コンソールで作成しておく必要がある。
#
# 使い方:
#   ./scripts/get-or-create-destination.sh <ACCOUNT_ID> <API_KEY> <OUTPUT_FILE>
# =============================================================================

set -euo pipefail

ACCOUNT_ID="$1"
API_KEY="$2"
OUTPUT_FILE="$3"

NERDGRAPH_URL="https://api.newrelic.com/graphql"

# -----------------------------------------------------------------------------
# WORKFLOW_AUTOMATION タイプの Destination を検索
# -----------------------------------------------------------------------------
SEARCH_QUERY=$(cat <<EOF
{
  "query": "{ actor { account(id: ${ACCOUNT_ID}) { aiNotifications { destinations(filters: { type: WORKFLOW_AUTOMATION }) { entities { id name type } } } } } }"
}
EOF
)

SEARCH_RESPONSE=$(curl -s -X POST "$NERDGRAPH_URL" \
  -H "Content-Type: application/json" \
  -H "API-Key: ${API_KEY}" \
  -d "$SEARCH_QUERY")

# 最初に見つかった WORKFLOW_AUTOMATION Destination のIDを取得
DEST_ID=$(echo "$SEARCH_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    entities = data['data']['actor']['account']['aiNotifications']['destinations']['entities']
    for e in entities:
        if e['type'] == 'WORKFLOW_AUTOMATION':
            print(e['id'])
            sys.exit(0)
    print('', file=sys.stderr)
    sys.exit(1)
except (KeyError, TypeError, json.JSONDecodeError) as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)

if [ -n "$DEST_ID" ]; then
  echo "{\"destination_id\": \"${DEST_ID}\"}" > "$OUTPUT_FILE"
  echo "Found Workflow Automation destination: ${DEST_ID}"
  exit 0
fi

echo "ERROR: No WORKFLOW_AUTOMATION destination found."
echo "Please create one manually in New Relic:"
echo "  1. Go to one.newrelic.com > All capabilities > Alerts > Destinations"
echo "  2. Click 'Workflow Automation'"
echo "  3. Enter a name and API Key, then click 'Save destination'"
exit 1
