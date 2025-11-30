#!/usr/bin/env bash
set -euo pipefail

# Folder where this script lives (so it works from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Elevate first, so everything (including downloads) runs as root ---
if [[ $EUID -ne 0 ]]; then
    echo "Administrator password required..."
    exec sudo "$0" "$@"
fi

# --- Download / update the rest of the scripts here ---
BASE_RAW="https://raw.githubusercontent.com/aazad612/free-mac-optimizer-suite/main"

SCRIPTS=(
  "siri.sh"
  "animator.sh"
  "icloud.sh"
  "spotlight.sh"
)

echo "Fetching latest optimization scripts..."
for f in "${SCRIPTS[@]}"; do
    echo "  → $f"
    curl -sSL -o "${SCRIPT_DIR}/${f}" "${BASE_RAW}/${f}"
done

echo "Setting execute permissions..."
chmod +x "${SCRIPT_DIR}/"*.sh

echo
echo "======================================"
echo "  Free Mac Optimizer Suite"
echo "======================================"
echo
echo "This tool will run:"
echo "  1) Siri optimization"
echo "  2) Animation optimization"
echo "  3) iCloud optimization"
echo "  4) Spotlight optimization"
echo
echo "Press Enter to continue, or Ctrl+C to cancel."
read -r _

echo
echo "Running with elevated permissions..."
echo

echo "▶ 1/4 – Siri optimization..."
"${SCRIPT_DIR}/siri.sh" -disable      || echo "⚠ Siri script failed."

echo
echo "▶ 2/4 – Animation optimization..."
"${SCRIPT_DIR}/animator.sh" -disable  || echo "⚠ Animation script failed."

echo
echo "▶ 3/4 – iCloud optimization..."
"${SCRIPT_DIR}/icloud.sh" -disable    || echo "⚠ iCloud script failed."

echo
echo "▶ 4/4 – Spotlight optimization..."
"${SCRIPT_DIR}/spotlight.sh" -disable || echo "⚠ Spotlight script failed."

echo
echo "✅ Finished. You can close this window."
read -r -p "Press Enter to close..."
exit 0

