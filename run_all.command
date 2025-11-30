#!/usr/bin/env bash
set -euo pipefail

# Folder where this script lives (so it works from anywhere)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Elevate first so everything runs as root & banner shows only once ---
if [[ $EUID -ne 0 ]]; then
    echo "Administrator password required..."
    exec sudo "$0" "$@"
fi

# --- Download / update all optimization scripts ---
BASE_RAW="https://raw.githubusercontent.com/aazad612/free-mac-optimizer-suite/main"

SCRIPTS=(
  "siri.sh"
  "animator.sh"
  "icloud.sh"
  "spotlight.sh"
  "telemetry.sh"
  "updates.sh"
  "suggestions.sh"
  "media_analysis.sh"
  "others.sh"
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
echo "  5) Telemetry optimization"
echo "  6) Updates optimization"
echo "  7) Suggestions optimization"
echo "  8) Media Analysis optimization"
echo "  9) Other macOS tweaks (Time Machine, Live Text, Helpers, Notifications)"
echo
echo "Press Enter to continue, or Ctrl+C to cancel."
read -r _

echo
echo "Running with elevated permissions..."
echo

echo "▶ 1/9 – Siri optimization..."
"${SCRIPT_DIR}/siri.sh" -disable            || echo "⚠ Siri script failed."

echo
echo "▶ 2/9 – Animation optimization..."
"${SCRIPT_DIR}/animator.sh" -disable        || echo "⚠ Animation script failed."

echo
echo "▶ 3/9 – iCloud optimization..."
"${SCRIPT_DIR}/icloud.sh" -disable          || echo "⚠ iCloud script failed."

echo
echo "▶ 4/9 – Spotlight optimization..."
"${SCRIPT_DIR}/spotlight.sh" -disable       || echo "⚠ Spotlight script failed."

echo
echo "▶ 5/9 – Telemetry optimization..."
"${SCRIPT_DIR}/telemetry.sh" -disable       || echo "⚠ Telemetry script failed."

echo
echo "▶ 6/9 – Updates optimization..."
"${SCRIPT_DIR}/updates.sh" -disable         || echo "⚠ Updates script failed."

echo
echo "▶ 7/9 – Suggestions optimization..."
"${SCRIPT_DIR}/suggestions.sh" -disable     || echo "⚠ Suggestions script failed."

echo
echo "▶ 8/9 – Media Analysis optimization..."
"${SCRIPT_DIR}/media_analysis.sh" -disable  || echo "⚠ Media analysis script failed."

echo
echo "▶ 9/9 – Other macOS tweaks..."
"${SCRIPT_DIR}/others.sh" -disable          || echo "⚠ Others script failed."

echo
echo "✅ Finished. You can close this window."
read -r -p "Press Enter to close..."
exit 0

