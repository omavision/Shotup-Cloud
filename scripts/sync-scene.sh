#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="${SHOTUP_API_BASE_URL:-http://127.0.0.1:8080}"

echo "Requesting dev access token..."
access_token="$("${SCRIPT_DIR}/dev-login.sh")"

echo "Syncing scene 22222222-2222-2222-2222-222222222222..."
curl -sS --fail-with-body -X POST "${BASE_URL}/api/v1/sync" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    -d '{
        "deviceID":"iphone-dev-001",
        "lastSyncToken":null,
        "changes":[
            {
                "entity":"scene",
                "operation":"upsert",
                "id":"22222222-2222-2222-2222-222222222222",
                "updatedAt":"2026-06-25T16:00:00Z",
                "payload":{
                    "projectID":"11111111-1111-1111-1111-111111111111",
                    "title":"Opening Scene",
                    "notes":"Opening sequence",
                    "sortOrder":"1"
                }
            }
        ]
    }'
printf '\n'
