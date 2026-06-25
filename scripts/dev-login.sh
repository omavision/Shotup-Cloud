#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${SHOTUP_API_BASE_URL:-http://127.0.0.1:8080}"

response="$(
    curl -sS --fail-with-body -X POST "${BASE_URL}/api/v1/auth/dev-login" \
        -H "Content-Type: application/json" \
        -d '{"appleUserID":"dev.apple.user.004","email":"dev4@shotup.cc","displayName":"Dev User 4"}'
)"

access_token="$(
    RESPONSE="${response}" python3 - <<'PY'
import json
import os
import sys

try:
    body = json.loads(os.environ["RESPONSE"])
    token = body.get("data", {}).get("accessToken")
except Exception:
    token = None

if not token:
    sys.exit(1)

print(token)
PY
)" || {
    echo "Failed to extract accessToken from dev-login response." >&2
    echo "${response}" >&2
    exit 1
}

printf '%s\n' "${access_token}"
