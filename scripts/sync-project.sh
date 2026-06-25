#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="${SHOTUP_API_BASE_URL:-http://127.0.0.1:8080}"

echo "Requesting dev access token..."
access_token="$("${SCRIPT_DIR}/dev-login.sh")"

echo "Syncing project 11111111-1111-1111-1111-111111111111..."
curl -sS --fail-with-body -X POST "${BASE_URL}/api/v1/sync" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    -d '{
        "deviceID":"iphone-dev-001",
        "lastSyncToken":null,
        "changes":[
            {
                "entity":"project",
                "operation":"upsert",
                "id":"11111111-1111-1111-1111-111111111111",
                "updatedAt":"2026-06-25T15:00:00Z",
                "payload":{
                    "title":"Synced Project",
                    "notes":"Created through sync engine"
                }
            }
        ]
    }'
printf '\n'
