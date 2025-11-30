#!/bin/zsh

# telemetry.sh
#
# Telemetry / diagnostics controller for macOS:
#   - Controls "send diagnostics & usage data" prefs.
#   - Disables/enables Apple analytics & crash reporting as much as possible.
#
# Modes:
#   ./telemetry.sh           → interactive prompt
#   ./telemetry.sh -disable  → disable immediately (no prompt)
#   ./telemetry.sh -enable   → enable immediately (no prompt)
#
# Fully verbose. No output is suppressed.

###############################################################################
# Helpers
###############################################################################

hr()  { printf '%s\n' "------------------------------------------------------------"; }
say() { printf '%s\n' "$*"; }
cmd() { echo "+ $*"; eval "$*"; echo; }

prompt_yes_no() {
  local q="$1"
  local d="yes"
  local a
  while true; do
    printf "%s [Y/n]: " "$q"
    read a
    a=$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')
    [[ -z "$a" ]] && a="$d"
    case "$a" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     say "[WARN] Please answer yes or no." ;;
    esac
  done
}

read_pref() {
  local dom="$1"
  local key="$2"
  echo "+ defaults read $dom $key"
  defaults read "$dom" "$key" 2>&1
}

yes_no_bool() {
  case "$1" in
    1|true)  echo "Yes" ;;
    0|false) echo "No" ;;
    *)       echo "Unknown" ;;
  esac
}

###############################################################################
# STATUS
###############################################################################

show_status() {
  hr
  say "Telemetry / Diagnostics — Current Status (Verbose)"
  hr

  say "[INFO] SubmitDiagInfo (system-level analytics prefs):"
  autosubmit=$(read_pref com.apple.SubmitDiagInfo AutoSubmit)
  thirdparty=$(read_pref com.apple.SubmitDiagInfo ThirdPartyDataSubmit)
  echo
  say "  Send diagnostics to Apple (AutoSubmit):        $(yes_no_bool "$autosubmit")"
  say "  Share diagnostics with app developers:         $(yes_no_bool "$thirdparty")"
  echo

  say "[INFO] analyticsd / diagnostic-related defaults (best-effort reads):"
  ad_enabled=$(read_pref com.apple.analyticsd AllowMixedDeviceIdentifiers)
  echo
  say "  AllowMixedDeviceIdentifiers (analyticsd):      $ad_enabled"
  echo

  say "[INFO] Telemetry / diagnostics related processes:"
  cmd "ps axo pid,comm | grep -Ei 'analyticsd|diagnosticd|logd|submitdiaginfo|spindump|ReportCrash|crashreporterd|awd|metric|symptomsd|corecaptured' | grep -v grep"
}

###############################################################################
# DISABLE: Turn off diagnostics / analytics (as much as possible)
###############################################################################

disable_telemetry() {
  hr
  say "[ACTION] DISABLING telemetry & diagnostics (analytics, crash reporting, etc.)"
  hr

  say "[STEP] Disabling 'Send diagnostics & usage data to Apple'"
  # These typically require sudo at system level
  cmd "sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit -bool false"
  cmd "sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo ThirdPartyDataSubmit -bool false"

  say
  say "[STEP] Disabling some analyticsd features (best-effort)"
  cmd "sudo defaults write /Library/Preferences/com.apple.analyticsd AllowMixedDeviceIdentifiers -bool false"

  hr
  say "[STEP] Attempting to unload telemetry-related daemons (best-effort)"
  hr

  TELEMETRY_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.analyticsd.plist"
    "/System/Library/LaunchDaemons/com.apple.spindump.plist"
    "/System/Library/LaunchDaemons/com.apple.crashreporterd.plist"
    "/System/Library/LaunchDaemons/com.apple.systemstatsd.plist"
    "/System/Library/LaunchDaemons/com.apple.symptomsd.plist"
    "/System/Library/LaunchDaemons/com.apple.corecaptured.plist"
  )

  for d in "${TELEMETRY_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[UNLOAD] $d"
      cmd "sudo launchctl unload -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  hr
  say "[STEP] Killing telemetry / diagnostics processes"
  hr

  for p in analyticsd diagnosticd submitdiaginfo spindump ReportCrash crashreporterd systemstatsd symptomsd corecaptured; do
    say "[KILL] $p"
    cmd "pgrep $p"
    cmd "sudo killall $p"
  done

  hr
  say "[STEP] Telemetry status AFTER disable:"
  hr
  show_status
  say "[NOTE] Some core processes may respawn; macOS really wants crash/diag plumbing alive."
  say "      But sending of analytics/diagnostic data is disabled at the preference level."
  say "[COMPLETE] Telemetry / diagnostics disabled as much as userland can manage."
}

###############################################################################
# ENABLE: Restore diagnostics / analytics
###############################################################################

enable_telemetry() {
  hr
  say "[ACTION] ENABLING telemetry & diagnostics (restore defaults)"
  hr

  say "[STEP] Enabling 'Send diagnostics & usage data to Apple'"
  cmd "sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo AutoSubmit -bool true"
  cmd "sudo defaults write /Library/Preferences/com.apple.SubmitDiagInfo ThirdPartyDataSubmit -bool true"

  say
  say "[STEP] Re-enabling analyticsd mixed identifiers (best-effort default)"
  cmd "sudo defaults write /Library/Preferences/com.apple.analyticsd AllowMixedDeviceIdentifiers -bool true"

  hr
  say "[STEP] Reloading telemetry-related daemons (best-effort)"
  hr

  TELEMETRY_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.analyticsd.plist"
    "/System/Library/LaunchDaemons/com.apple.spindump.plist"
    "/System/Library/LaunchDaemons/com.apple.crashreporterd.plist"
    "/System/Library/LaunchDaemons/com.apple.systemstatsd.plist"
    "/System/Library/LaunchDaemons/com.apple.symptomsd.plist"
    "/System/Library/LaunchDaemons/com.apple.corecaptured.plist"
  )

  for d in "${TELEMETRY_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[LOAD] $d"
      cmd "sudo launchctl load -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  hr
  say "[STEP] Telemetry status AFTER enable:"
  hr
  show_status
  say "[COMPLETE] Telemetry / diagnostics enabled (as close to stock as possible)."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "   Telemetry / Diagnostics Controller (Verbose, Flags)"
say "============================================================"
say

# Flag mode
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate DISABLE (no prompt)"
  disable_telemetry
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate ENABLE (no prompt)"
  enable_telemetry
  exit 0
fi

# Interactive mode
show_status

if prompt_yes_no "Disable telemetry & diagnostics (analytics, crash reports, etc.)?" ; then
  disable_telemetry
else
  enable_telemetry
fi

hr
say "FINAL STATUS"
show_status
say "Done."

