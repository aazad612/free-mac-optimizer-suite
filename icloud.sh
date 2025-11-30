#!/bin/zsh

# icloud_sync_control.sh
#
# One-question interactive mode:
#   "Disable iCloud Sync? [Y/n]"
#
# Command-line flags:
#   -disable     → disable all iCloud sync, no questions
#   -enable      → enable all iCloud sync, no questions
#
# Fully verbose. No suppressed output.

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
      *)     say "[WARN] Please type yes or no." ;;
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
# STATUS
###############################################################################

show_status() {
  hr
  say "iCloud Sync — Current Status (Verbose)"
  hr

  say "[INFO] iCloud Drive auto-save:"
  drive=$(read_pref NSGlobalDomain NSDocumentSaveNewDocumentsToCloud)
  echo

  say "[INFO] Universal Clipboard:"
  ucb=$(read_pref com.apple.coreservices.useractivityd ActivityAdvertisingAllowed)
  ucr=$(read_pref com.apple.coreservices.useractivityd ActivityReceivingAllowed)
  echo

  say "[INFO] Photos Sync:"
  photos=$(read_pref com.apple.iLifePhotoStream Enabled)
  streams=$(read_pref com.apple.iLifePhotoStream SharedStreamsEnabled)
  echo

  say "[INFO] Safari iCloud Tabs:"
  tabs=$(read_pref com.apple.Safari CloudTabsEnabled)
  echo

  say "[INFO] iCloud-related processes:"
  cmd "ps axo pid,comm | grep -Ei 'icloud|cloud|bird|nsurlsessiond|ubd|photolibraryd|photoanalysisd|findmy|cfprefsd' | grep -v grep"

  say "=== Interpreted ==="
  say "iCloud Drive autosave:     $( [[ \"$drive\" == \"1\" ]] && echo Enabled || echo Disabled )"
  say "Universal Clipboard:        $( [[ \"$ucb\" == \"1\" ]] && echo Enabled || echo Disabled )"
  say "Photos Sync:                $( [[ \"$photos\" == \"1\" ]] && echo Enabled || echo Disabled )"
  say "Shared Streams:             $( [[ \"$streams\" == \"1\" ]] && echo Enabled || echo Disabled )"
  say "Safari Cloud Tabs:          $( [[ \"$tabs\" == \"1\" ]] && echo Enabled || echo Disabled )"
  echo
}

###############################################################################
# DISABLE EVERYTHING
###############################################################################

disable_icloud() {
  hr
  say "[ACTION] DISABLING ALL iCloud Sync"
  hr

  cmd "defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false"
  cmd "defaults write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false"
  cmd "defaults write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false"
  cmd "defaults write com.apple.iLifePhotoStream Enabled -bool false"
  cmd "defaults write com.apple.iLifePhotoStream SharedStreamsEnabled -bool false"
  cmd "defaults write com.apple.Safari CloudTabsEnabled -bool false"

  hr
  say "[ACTION] Killing cloud sync daemons"
  hr

  for p in bird cloudd nsurlsessiond ubd ubdpd photolibraryd photoanalysisd findmydeviced cfprefsd; do
    say "[KILL] $p"
    cmd "pgrep $p"
    cmd "killall $p"
  done

  say "[COMPLETE] iCloud sync disabled."
}

###############################################################################
# ENABLE EVERYTHING (RESTORE DEFAULT SYNC)
###############################################################################

enable_icloud() {
  hr
  say "[ACTION] ENABLING iCloud Sync (restoring defaults)"
  hr

  cmd "defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool true"
  cmd "defaults write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool true"
  cmd "defaults write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool true"
  cmd "defaults write com.apple.iLifePhotoStream Enabled -bool true"
  cmd "defaults write com.apple.iLifePhotoStream SharedStreamsEnabled -bool true"
  cmd "defaults write com.apple.Safari CloudTabsEnabled -bool true"

  hr
  say "[ACTION] Launching daemons"
  hr

  for agent in com.apple.bird com.apple.cloudd; do
    say "[LOAD] $agent"
    cmd "launchctl load -w /System/Library/LaunchAgents/$agent.plist"
  done

  say "[COMPLETE] iCloud sync enabled."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "          iCloud Sync Control (Interactive + Flags)"
say "============================================================"
say

# --- Command Line Flags (no prompt) ---
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Flag detected: -disable (no confirmation)"
  disable_icloud
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Flag detected: -enable (no confirmation)"
  enable_icloud
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

# --- Interactive Mode ---
show_status

if prompt_yes_no "Disable iCloud Sync?" "yes"; then
  disable_icloud
else
  enable_icloud
fi

hr
say "FINAL STATUS"
show_status
say "Done."

