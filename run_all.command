#!/usr/bin/env bash
set -euo pipefail

# Folder where this script lives (so it works from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "  Free Mac Optimizer Suite"
echo "======================================"
echo
echo "This tool will run:"
echo "  1) Siri optimization"
echo "  2) Animation optimization"
echo "  3) iCloud optimization"
echo
echo "Press Enter to continue, or Ctrl+C to cancel."
read -r _

echo
echo "▶ 1/3 – Siri optimization..."
"${SCRIPT_DIR}/siri.sh" -disable || echo "⚠ Siri script failed."

echo
echo "▶ 2/3 – Animation optimization..."
"${SCRIPT_DIR}/animator.sh" -disable || echo "⚠ Animator script failed."

echo
echo "▶ 3/3 – iCloud optimization..."
"${SCRIPT_DIR}/icloud.sh" -disable || echo "⚠ iCloud script failed."

echo
echo "✅ Finished. You can close this window."
read -r -p "Press Enter to close..."

