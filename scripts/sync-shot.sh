#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_URL="${SHOTUP_API_BASE_URL:-http://127.0.0.1:8080}"

echo "Requesting dev access token..."
access_token="$("${SCRIPT_DIR}/dev-login.sh")"

echo "Syncing shot 33333333-3333-3333-3333-333333333333..."
curl -sS --fail-with-body -X POST "${BASE_URL}/api/v1/sync" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${access_token}" \
    -d '{
        "deviceID":"iphone-dev-001",
        "lastSyncToken":null,
        "changes":[
            {
                "entity":"shot",
                "operation":"upsert",
                "id":"33333333-3333-3333-3333-333333333333",
                "updatedAt":"2026-06-25T17:00:00Z",
                "payload":{
                    "sceneID":"22222222-2222-2222-2222-222222222222",
                    "title":"Shot 1A",
                    "notes":"First synced shot",
                    "shotSize":"Wide",
                    "cameraMovement":"Static",
                    "lensMM":"35",
                    "sortOrder":"1"
                }
            }
        ]
    }'
printf '\n'
