#!/bin/zsh

# siri_ai_disable.sh
#
# Chatty "begware" script:
#  - Shows real Siri / Apple Intelligence status in human terms.
#  - Shows how many Siri/AI processes are running.
#  - Asks if you want to disable them (recommended).
#  - If yes, disables daemons + kills processes + flips prefs.
#
# Requires: macOS (Sequoia/Sonoma+), zsh, sudo for disabling.

###############################################################################
# Pretty printing helpers
###############################################################################

hr() { printf '%s\n' "------------------------------------------------------------"; }

say() { printf '%s\n' "$*"; }

prompt_yes_no() {
  # $1 = question, $2 = default ("yes" or "no")
  local question="$1"
  local default="$2"
  local answer

  while true; do
    if [[ "$default" == "yes" ]]; then
      printf "%s [Y/n]: " "$question"
    else
      printf "%s [y/N]: " "$question"
    fi

    read answer
    answer=$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')

    if [[ -z "$answer" ]]; then
      answer="$default"
    fi

    case "$answer" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     say "[WARN] Please type yes or no." ;;
    esac
  done
}

###############################################################################
# Detection functions
###############################################################################

get_siri_status() {
  local v
  v=$(defaults read com.apple.assistant.support "Assistant Enabled" 2>/dev/null || echo "MISSING")

  case "$v" in
    1) echo "Enabled" ;;
    0) echo "Disabled" ;;
    MISSING) echo "Unknown (no explicit setting, usually behaves like Enabled)" ;;
    *) echo "Unknown ($v)" ;;
  esac
}

get_hey_siri_status() {
  local v
  v=$(/usr/libexec/PlistBuddy -c "Print :VoiceTriggerEnabled" "$HOME/Library/Preferences/com.apple.Siri.plist" 2>/dev/null || echo "MISSING")

  case "$v" in
    true)  echo "On" ;;
    false) echo "Off" ;;
    MISSING) echo "Unknown (no preference stored)" ;;
    *) echo "Unknown ($v)" ;;
  esac
}

get_ai_inline_status() {
  local v
  v=$(defaults read com.apple.IntelligencePlatform InlineSuggestionEnabled 2>/dev/null || \
      defaults read com.apple.IntegrityCheck InlineSuggestionEnabled 2>/dev/null || \
      echo "MISSING")

  case "$v" in
    1) echo "On (inline AI writing suggestions enabled)" ;;
    0) echo "Off" ;;
    MISSING) echo "Off / not configured" ;;
    *) echo "Unknown ($v)" ;;
  esac
}

get_ai_optin_status() {
  local v
  v=$(defaults read com.apple.intelligenceplatformd OptInStatus 2>/dev/null || echo "MISSING")

  case "$v" in
    2) echo "Fully opted-in to Apple Intelligence" ;;
    1) echo "Partially set up" ;;
    0) echo "Not opted-in / disabled" ;;
    MISSING) echo "Not configured (treated as disabled)" ;;
    *) echo "Unknown ($v)" ;;
  esac
}

get_ai_cloud_status() {
  local v
  v=$(defaults read com.apple.intelligenceplatformd DisableCloudIntelligence 2>/dev/null || echo "MISSING")

  case "$v" in
    0) echo "Cloud AI allowed" ;;
    1) echo "Cloud AI blocked (this is the privacy-friendly state)" ;;
    MISSING) echo "Unknown (no explicit setting)" ;;
    *) echo "Unknown ($v)" ;;
  esac
}

summarize_ai_overall() {
  local inline optin cloud

  inline=$(get_ai_inline_status)
  optin=$(get_ai_optin_status)
  cloud=$(get_ai_cloud_status)

  if [[ "$inline" == On* ]] || [[ "$optin" == "Fully opted-in"* ]] || [[ "$optin" == "Partially set up" ]]; then
    echo "Apple Intelligence: Likely ENABLED or partially enabled."
  elif [[ "$inline" == Off* ]] && [[ "$optin" == "Not opted-in"* ]] && [[ "$cloud" == "Cloud AI blocked"* ]]; then
    echo "Apple Intelligence: Fully DISABLED (good for performance & privacy)."
  else
    echo "Apple Intelligence: Mixed/unclear state (some pieces may still be running)."
  fi
}

get_siri_ai_processes() {
  # Return list of Siri/AI related processes, one per line.
  local patterns
  patterns='assistantd|corespeechd|siriactionsd|siriinferenced|sirittsd|siriknowledged|intelligenceplatformd|naturallanguaged|biomed|biomesyncd|knowledge-agent'

  # Use pgrep -lf to show PID + command, ignore failures
  pgrep -lf "$patterns" 2>/dev/null || true
}

print_siri_ai_status() {
  hr
  say "Siri / Apple Intelligence — Current Status (Human Friendly)"
  hr

  local siri hey ai_inline ai_optin ai_cloud ai_summary
  siri=$(get_siri_status)
  hey=$(get_hey_siri_status)
  ai_inline=$(get_ai_inline_status)
  ai_optin=$(get_ai_optin_status)
  ai_cloud=$(get_ai_cloud_status)
  ai_summary=$(summarize_ai_overall)

  say "Siri assistant:         $siri"
  say "“Hey Siri” wake word:   $hey"
  say "AI inline suggestions:  $ai_inline"
  say "AI opt-in status:       $ai_optin"
  say "Cloud AI usage:         $ai_cloud"
  say
  say "$ai_summary"
  say

  hr
  say "Siri / AI background processes currently running"
  hr

  local procs count
  procs=$(get_siri_ai_processes)
  count=$(printf '%s\n' "$procs" | sed '/^\s*$/d' | wc -l | tr -d ' ')

  if [[ "$count" -eq 0 ]]; then
    say "✅ No Siri / Apple Intelligence background processes are currently running."
  else
    say "⚠️  There are $count Siri / Apple Intelligence related processes running right now:"
    say
    printf '%s\n' "$procs"
    say
    say "These are daemons and services that most users don't need, but they still"
    say "consume CPU, memory, and disk, especially on older Macs."
  fi

  echo
}

###############################################################################
# Disabling logic
###############################################################################

disable_siri_ai_daemons() {
  hr
  say "STEP 1: Disabling Siri / Apple Intelligence launch daemons and agents…"
  hr

  local TARGETS=(
    "com.apple.assistant_service"
    "com.apple.assistantd"
    "com.apple.assistant_cdmd"
    "com.apple.corespeechd"
    "com.apple.corespeechd_system"
    "com.apple.siriactionsd"
    "com.apple.Siri.agent"
    "com.apple.siriinferenced"
    "com.apple.SiriTTSTrainingAgent"
    "com.apple.sirittsd"
    "com.apple.siriknowledged"
    "com.apple.intelligenceflowd"
    "com.apple.intelligencecontextd"
    "com.apple.intelligenceplatformd"
    "com.apple.naturallanguaged"
    "com.apple.biomed"
    "com.apple.BiomeAgent"
    "com.apple.biomesyncd"
    "com.apple.ContextStoreAgent"
    "com.apple.knowledge-agent"
    "com.apple.knowledgeconstructiond"
    "com.apple.UsageTrackingAgent"
    "com.apple.generativeexperiencesd"
    "com.apple.siri.context.service"
    "com.apple.triald"
    "com.apple.triald.system"
  )

  # Pre-auth with sudo so user gets one password prompt
  say "[INFO] Requesting sudo permission (needed to disable system daemons)…"
  sudo -v || { say "[ERROR] sudo auth failed; cannot disable system services."; return 1; }

  for label in "${TARGETS[@]}"; do
    say "→ Disabling: $label"
    sudo launchctl bootout "system/$label" 2>/dev/null || true
    sudo launchctl bootout "gui/$UID/$label" 2>/dev/null || true
    sudo launchctl disable "system/$label" 2>/dev/null || true
    sudo launchctl disable "gui/$UID/$label" 2>/dev/null || true
  done

  echo
  hr
  say "STEP 2: Killing any remaining Siri / AI processes…"
  hr

  sudo pkill assistantd          2>/dev/null || true
  sudo pkill corespeechd         2>/dev/null || true
  sudo pkill siriactionsd        2>/dev/null || true
  sudo pkill siriinferenced      2>/dev/null || true
  sudo pkill sirittsd            2>/dev/null || true
  sudo pkill siriknowledged      2>/dev/null || true
  sudo pkill intelligenceplatformd 2>/dev/null || true
  sudo pkill naturallanguaged    2>/dev/null || true
  sudo pkill biomed              2>/dev/null || true
  sudo pkill biomesyncd          2>/dev/null || true
  sudo pkill knowledge-agent     2>/dev/null || true

  echo
  hr
  say "STEP 3: Flipping preferences to 'OFF' for Siri / AI / Cloud AI…"
  hr

  sudo defaults write /Library/Preferences/com.apple.assistant.support "Assistant Enabled" -bool false
  defaults write com.apple.Siri "VoiceTriggerEnabled" -bool false

  defaults write com.apple.IntegrityCheck InlineSuggestionEnabled -int 0
  defaults write com.apple.IntelligencePlatform InlineSuggestionEnabled -int 0
  defaults write com.apple.intelligenceplatformd DisableCloudIntelligence -int 1
  defaults write com.apple.intelligenceplatformd OptInStatus -int 0

  say "✓ Siri assistant turned OFF"
  say "✓ “Hey Siri” turned OFF"
  say "✓ Apple Intelligence suggestions turned OFF"
  say "✓ Cloud-based AI blocked"
  say "✓ Opt-in status reset to 'not opted-in'"

  echo
  hr
  say "STEP 4: Verifying that processes are no longer running…"
  hr

  local procs_after count_after
  procs_after=$(get_siri_ai_processes)
  count_after=$(printf '%s\n' "$procs_after" | sed '/^\s*$/d' | wc -l | tr -d ' ')

  if [[ "$count_after" -eq 0 ]]; then
    say "✅ All Siri / Apple Intelligence background processes appear to be stopped."
  else
    say "⚠️ Some Siri / AI processes are STILL running (macOS may resurrect a few):"
    printf '%s\n' "$procs_after"
  fi

  echo
  say "A reboot is recommended to guarantee everything stays down."
  echo
}

###############################################################################
# Main flow
###############################################################################

clear 2>/dev/null || true
say "============================================================"
say "  Siri + Apple Intelligence Disabler (Chatty Begware Edition)"
say "============================================================"
say
say "This script will:"
say "  • Show you the REAL Siri / Apple Intelligence status in plain English."
say "  • Show you how many background Siri/AI processes are running."
say "  • Offer to disable all of it (recommended for older/slow Macs)."
say "  • If you say YES, it will stop + disable daemons and turn off prefs."
say
hr
print_siri_ai_status

if prompt_yes_no "Do you want to DISABLE all Siri + Apple Intelligence background services now? (recommended)" "yes"; then
  say
  say "[ACTION] Proceeding to disable Siri + Apple Intelligence…"
  disable_siri_ai_daemons
else
  say
  say "[INFO] Leaving Siri + Apple Intelligence as-is. No changes made."
  exit 0
fi

hr
say "FINAL STATUS (after changes)"
hr
print_siri_ai_status
say "Done. If you found this useful, consider tipping the author a dollar 🙃"

