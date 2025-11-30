#!/bin/zsh

# siri_ai_control.sh
#
# Fully reversible controller for:
#   - Siri (assistantd, voice trigger, UI)
#   - Apple Intelligence (inline suggestions, on-device inference, cloud AI)
#
# Modes:
#   ./siri_ai_control.sh           → interactive prompt
#   ./siri_ai_control.sh -disable  → disable everything immediately
#   ./siri_ai_control.sh -enable   → enable everything immediately
#
# Fully verbose — no output hidden.

###############################################################################
# Helpers
###############################################################################

hr()  { printf '%s\n' "------------------------------------------------------------"; }
say() { printf '%s\n' "$*"; }
cmd() { echo "+ $*"; eval "$*"; echo; }

prompt_yes_no() {
  local q="$1"
  while true; do
    printf "%s [Y/n]: " "$q"
    read a
    a=$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')
    [[ -z "$a" ]] && a="yes"
    case "$a" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     say "[WARN] Please enter yes or no." ;;
    esac
  done
}

read_pref() {
  local dom="$1"
  local key="$2"
  echo "+ defaults read $dom $key"
  defaults read "$dom" "$key" 2>&1
}

###############################################################################
# Status
###############################################################################

show_status() {
  hr
  say "Siri + Apple Intelligence — Current Status (Verbose)"
  hr

  say "[INFO] Siri Assistant enabled:"
  assistant=$(read_pref com.apple.Siri StatusMenuVisible)
  echo

  say "[INFO] Voice Trigger (Hey Siri):"
  voicetrig=$(read_pref com.apple.Siri VoiceTriggerUserEnabled)
  echo

  say "[INFO] Inline AI Suggestions:"
  inline=$(read_pref com.apple.corespotlightui InlineSuggestionsEnabled)
  echo

  say "[INFO] AI Cloud Intelligence Allowed:"
  cloud=$(read_pref com.apple.IntelligencePlatformCore DisableCloudIntelligence)
  echo

  say "[INFO] AI Opt-in Status:"
  optin=$(read_pref com.apple.IntelligencePlatformCore UserOptIn)
  echo

  say "[INFO] Active Siri / AI daemons:"
  cmd "ps axo pid,comm | grep -Ei 'siri|assistant|intelligence|inference|naturallanguage|knowledge|suggest' | grep -v grep"
}

###############################################################################
# DISABLE EVERYTHING
###############################################################################

disable_siri_ai() {
  hr
  say "[ACTION] DISABLING Siri + Apple Intelligence"
  hr

  # Siri assistant
  cmd "defaults write com.apple.Siri StatusMenuVisible -bool false"
  cmd "defaults write com.apple.Siri SiriPrefStashedStatusMenuVisible -bool false"
  cmd "defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false"

  # AI suggestions + cloud AI
  cmd "defaults write com.apple.corespotlightui InlineSuggestionsEnabled -int 0"
  cmd "defaults write com.apple.IntelligencePlatformCore DisableCloudIntelligence -int 1"
  cmd "defaults write com.apple.IntelligencePlatformCore UserOptIn -int 0"

  hr
  say "[ACTION] Disabling all Siri/AI launch agents"
  hr

  for target in \
    system/com.apple.assistantd \
    system/com.apple.siriknowledged \
    system/com.apple.siriinferenced \
    system/com.apple.sirittsd \
    system/com.apple.intelligenceplatformd \
    gui/$UID/com.apple.Siri.agent \
    gui/$UID/com.apple.assistant_service \
    gui/$UID/com.apple.siriknowledged \
    gui/$UID/com.apple.siriinferenced \
    gui/$UID/com.apple.sirittsd \
    gui/$UID/com.apple.intelligenceplatformd; do

      say "[DISABLE] launchctl disable $target"
      cmd "launchctl disable $target"
  done

  hr
  say "[ACTION] Killing Siri/AI processes"
  hr

  for p in assistantd siriknowledged siriinferenced sirittsd intelligenceplatformd naturallanguaged biomed; do
    say "[KILL] $p"
    cmd "pgrep $p"
    cmd "killall $p"
  done

  say "[COMPLETE] Siri + AI disabled."
}

###############################################################################
# ENABLE EVERYTHING (FULL RESTORE)
###############################################################################

enable_siri_ai() {
  hr
  say "[ACTION] ENABLING Siri + Apple Intelligence (Full Restore)"
  hr

  # Siri assistant
  cmd "defaults write com.apple.Siri StatusMenuVisible -bool true"
  cmd "defaults write com.apple.Siri SiriPrefStashedStatusMenuVisible -bool true"
  cmd "defaults write com.apple.Siri VoiceTriggerUserEnabled -bool true"

  # AI Intelligence (full restore)
  cmd "defaults write com.apple.corespotlightui InlineSuggestionsEnabled -int 1"
  cmd "defaults write com.apple.IntelligencePlatformCore DisableCloudIntelligence -int 0"
  cmd "defaults write com.apple.IntelligencePlatformCore UserOptIn -int 2"

  hr
  say "[ACTION] Re-enabling all Siri/AI launch agents"
  hr

  for target in \
    system/com.apple.assistantd \
    system/com.apple.siriknowledged \
    system/com.apple.siriinferenced \
    system/com.apple.sirittsd \
    system/com.apple.intelligenceplatformd \
    gui/$UID/com.apple.Siri.agent \
    gui/$UID/com.apple.assistant_service \
    gui/$UID/com.apple.siriknowledged \
    gui/$UID/com.apple.siriinferenced \
    gui/$UID/com.apple.sirittsd \
    gui/$UID/com.apple.intelligenceplatformd; do

      say "[ENABLE] launchctl enable $target"
      cmd "launchctl enable $target"
  done

  hr
  say "[ACTION] Triggering Siri/AI services to start"
  hr

  # These kick-start Siri & AI immediately
  cmd "launchctl kickstart -k system/com.apple.assistantd"
  cmd "launchctl kickstart -k system/com.apple.siriknowledged"
  cmd "launchctl kickstart -k system/com.apple.siriinferenced"
  cmd "launchctl kickstart -k system/com.apple.sirittsd"
  cmd "launchctl kickstart -k system/com.apple.intelligenceplatformd"

  # and user agents
  cmd "launchctl kickstart -k gui/$UID/com.apple.Siri.agent"
  cmd "launchctl kickstart -k gui/$UID/com.apple.assistant_service"
  cmd "launchctl kickstart -k gui/$UID/com.apple.siriknowledged"
  cmd "launchctl kickstart -k gui/$UID/com.apple.siriinferenced"
  cmd "launchctl kickstart -k gui/$UID/com.apple.sirittsd"
  cmd "launchctl kickstart -k gui/$UID/com.apple.intelligenceplatformd"

  say "[COMPLETE] Siri + Apple Intelligence restored."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "   Siri + Apple Intelligence Controller (Verbose, Flags)"
say "============================================================"
say

# Flag mode
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate disable (no prompt)"
  disable_siri_ai
  hr
  show_status
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate enable (no prompt)"
  enable_siri_ai
  hr
  show_status
  exit 0
fi

# Interactive mode
show_status

if prompt_yes_no "Disable Siri + Apple Intelligence?" ; then
  disable_siri_ai
else
  enable_siri_ai
fi

hr
say "FINAL STATUS"
show_status
say "Done."

