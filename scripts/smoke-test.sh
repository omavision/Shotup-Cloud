#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running Shotup sync smoke test..."
echo

"${SCRIPT_DIR}/sync-project.sh"
echo

"${SCRIPT_DIR}/sync-scene.sh"
echo

"${SCRIPT_DIR}/sync-shot.sh"
echo

"${SCRIPT_DIR}/sync-download.sh"
echo

echo "Smoke test completed."
