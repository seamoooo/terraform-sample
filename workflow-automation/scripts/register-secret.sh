#!/bin/bash
# =============================================================================
# register-secret.sh
# =============================================================================
# New Relic Secrets Management にシークレットを登録する。
# 既に同じ namespace / key が存在する場合は更新（新しいバージョンが作成される）。
#
# 参照: https://qiita.com/MarthaS/items/e90deb3a077c65f1500c
#
# 環境変数で値を受け取る（コマンドライン引数に渡すと ps などから見えるため）:
#   NR_ACCOUNT_ID       New Relic アカウント ID
#   NR_API_KEY          New Relic User API Key
#   NR_REGION           US / EU（省略時は US）
#   SECRET_NAMESPACE    シークレットの namespace（例: slack）
#   SECRET_KEY          シークレットの key（例: sre_slack_token）
#   SECRET_VALUE        シークレットの値
#   SECRET_DESCRIPTION  説明（省略可）
# =============================================================================

set -euo pipefail

: "${NR_ACCOUNT_ID:?NR_ACCOUNT_ID is required}"
: "${NR_API_KEY:?NR_API_KEY is required}"
: "${SECRET_NAMESPACE:?SECRET_NAMESPACE is required}"
: "${SECRET_KEY:?SECRET_KEY is required}"
: "${SECRET_VALUE:?SECRET_VALUE is required}"
NR_REGION="${NR_REGION:-US}"
SECRET_DESCRIPTION="${SECRET_DESCRIPTION:-}"

if [ "$(printf '%s' "$NR_REGION" | tr '[:lower:]' '[:upper:]')" = "EU" ]; then
  NERDGRAPH_URL="https://api.eu.newrelic.com/graphql"
else
  NERDGRAPH_URL="https://api.newrelic.com/graphql"
fi

# -----------------------------------------------------------------------------
# GraphQL ペイロードを組み立てる（値のエスケープは python 側で行う）
# -----------------------------------------------------------------------------
build_payload() {
  python3 -c '
import json, os, sys

op = sys.argv[1]
scope = "scope: {type: ACCOUNT, id: %s}" % json.dumps(os.environ["NR_ACCOUNT_ID"])
namespace = json.dumps(os.environ["SECRET_NAMESPACE"])
key = json.dumps(os.environ["SECRET_KEY"])
value = json.dumps(os.environ["SECRET_VALUE"])
description = json.dumps(os.environ.get("SECRET_DESCRIPTION", ""))

if op == "create":
    query = ("mutation { secretsManagementCreateSecret("
             "%s, namespace: %s, key: %s, description: %s, value: %s"
             ") { key latestVersion } }") % (scope, namespace, key, description, value)
else:
    query = ("mutation { secretsManagementUpdateSecret("
             "%s, namespace: %s, key: %s, value: %s"
             ") { key latestVersion } }") % (scope, namespace, key, value)

print(json.dumps({"query": query}))
' "$1"
}

call_nerdgraph() {
  curl -s -X POST "$NERDGRAPH_URL" \
    -H "Content-Type: application/json" \
    -H "API-Key: ${NR_API_KEY}" \
    -d @-
}

# レスポンスを検証し、成功なら latestVersion を、失敗ならエラーメッセージを返す
check_response() {
  python3 -c '
import json, sys

field = sys.argv[1]
raw = sys.stdin.read()

try:
    data = json.loads(raw)
except json.JSONDecodeError:
    print("invalid JSON response: %s" % raw[:500], file=sys.stderr)
    sys.exit(2)

errors = data.get("errors") or []
if errors:
    print("; ".join(e.get("message", str(e)) for e in errors), file=sys.stderr)
    sys.exit(3)

result = (data.get("data") or {}).get(field)
if not result:
    print("no data returned: %s" % raw[:500], file=sys.stderr)
    sys.exit(2)

print(result.get("latestVersion", ""))
' "$1"
}

# -----------------------------------------------------------------------------
# 1. 作成を試みる
# -----------------------------------------------------------------------------
CREATE_RESPONSE=$(build_payload create | call_nerdgraph)

if RESULT=$(printf '%s' "$CREATE_RESPONSE" | check_response secretsManagementCreateSecret 2>&1); then
  echo "Secret created: ${SECRET_NAMESPACE}:${SECRET_KEY} (version ${RESULT})"
  exit 0
fi

# -----------------------------------------------------------------------------
# 2. 既に存在する場合は更新する
# -----------------------------------------------------------------------------
case "$RESULT" in
  *already*|*Already*|*exists*|*Exists*|*duplicate*|*Duplicate*|*DUPLICATE*)
    UPDATE_RESPONSE=$(build_payload update | call_nerdgraph)

    if RESULT=$(printf '%s' "$UPDATE_RESPONSE" | check_response secretsManagementUpdateSecret 2>&1); then
      echo "Secret updated: ${SECRET_NAMESPACE}:${SECRET_KEY} (version ${RESULT})"
      exit 0
    fi

    echo "ERROR: failed to update secret '${SECRET_NAMESPACE}:${SECRET_KEY}': ${RESULT}" >&2
    exit 1
    ;;
esac

echo "ERROR: failed to create secret '${SECRET_NAMESPACE}:${SECRET_KEY}': ${RESULT}" >&2
exit 1
