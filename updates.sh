#!/bin/zsh

# updates.sh
#
# Controls macOS Software Update + App Store background update noise:
#   - Disables/enables automatic macOS update checks
#   - Disables/enables automatic macOS downloads
#   - Disables/enables App Store background update checks
#   - Kills update daemons aggressively
#
# Modes:
#   ./updates.sh           → interactive
#   ./updates.sh -disable  → disable immediately (no prompt)
#   ./updates.sh -enable   → enable immediately (no prompt)
#
# Fully verbose. No hidden output.

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
      *) say "[WARN] Please answer yes or no." ;;
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
    1|true) echo "Yes" ;;
    0|false) echo "No" ;;
    *) echo "Unknown" ;;
  esac
}

###############################################################################
# STATUS
###############################################################################

show_status() {
  hr
  say "Software Update / App Store — Current Status"
  hr

  say "[INFO] Software Update prefs (system-level):"
  cmd "softwareupdate --schedule"
  echo

  say "[INFO] User defaults related to auto-updates:"
  au_check=$(read_pref com.apple.SoftwareUpdate AutomaticCheckEnabled)
  au_download=$(read_pref com.apple.SoftwareUpdate AutomaticDownload)
  au_critical=$(read_pref com.apple.SoftwareUpdate CriticalUpdateInstall)
  au_config=$(read_pref com.apple.commerce AutoUpdate)
  echo

  say "  Automatic Check:      $(yes_no_bool "$au_check")"
  say "  Automatic Download:   $(yes_no_bool "$au_download")"
  say "  Critical Updates:     $(yes_no_bool "$au_critical")"
  echo
  say "  App Store AutoUpdate: $(yes_no_bool "$au_config")"
  echo

  say "[INFO] Update-related processes:"
  cmd "ps axo pid,comm | grep -Ei 'softwareupdate|appstore|commerce|storeassetd|store|mdmclient|installd' | grep -v grep"
}

###############################################################################
# DISABLE
###############################################################################

disable_updates() {
  hr
  say "[ACTION] DISABLING System + App Store background updates"
  hr

  say "[STEP] Disabling software update schedule"
  cmd "sudo softwareupdate --schedule off"

  say "[STEP] Disabling user auto-update prefs"
  cmd "defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false"
  cmd "defaults write com.apple.SoftwareUpdate AutomaticDownload -bool false"
  cmd "defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool false"

  say "[STEP] Disabling App Store auto updates"
  cmd "defaults write com.apple.commerce AutoUpdate -bool false"

  hr
  say "[STEP] Unloading update-related launchd jobs (best-effort)"
  hr

  UPDATE_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.softwareupdated.plist"
    "/System/Library/LaunchDaemons/com.apple.storeassetd.plist"
    "/System/Library/LaunchDaemons/com.apple.installd.plist"
  )

  for d in "${UPDATE_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[UNLOAD] $d"
      cmd "sudo launchctl unload -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  hr
  say "[STEP] Killing update / App Store related processes"
  hr

  for p in softwareupdate appstoreagent storeassetd installd storeaccountd commerce; do
    say "[KILL] $p"
    cmd "pgrep $p"
    cmd "sudo killall $p"
  done

  hr
  say "[STEP] Software Update AFTER disable:"
  hr
  cmd "softwareupdate --schedule"
  cmd "ps axo pid,comm | grep -Ei 'softwareupdate|appstore|commerce|storeassetd|store|installd' | grep -v grep"

  say "[COMPLETE] Background updates disabled. Manual updates still work."
}

###############################################################################
# ENABLE
###############################################################################

enable_updates() {
  hr
  say "[ACTION] ENABLING System + App Store background updates"
  hr

  say "[STEP] Enabling software update schedule"
  cmd "sudo softwareupdate --schedule on"

  say "[STEP] Restoring user auto-update prefs"
  cmd "defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true"
  cmd "defaults write com.apple.SoftwareUpdate AutomaticDownload -bool true"
  cmd "defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -bool true"

  say "[STEP] Enabling App Store auto updates"
  cmd "defaults write com.apple.commerce AutoUpdate -bool true"

  hr
  say "[STEP] Loading update-related launchd jobs (best-effort)"
  hr

  UPDATE_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.softwareupdated.plist"
    "/System/Library/LaunchDaemons/com.apple.storeassetd.plist"
    "/System/Library/LaunchDaemons/com.apple.installd.plist"
  )

  for d in "${UPDATE_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[LOAD] $d"
      cmd "sudo launchctl load -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  hr
  say "[STEP] Software Update AFTER enable:"
  hr
  cmd "softwareupdate --schedule"
  cmd "ps axo pid,comm | grep -Ei 'softwareupdate|appstore|commerce|storeassetd|store|installd' | grep -v grep"

  say "[COMPLETE] Background updates enabled."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say " Software Update / App Store Controller (Verbose, Flags)"
say "============================================================"
say

# Flag mode
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate DISABLE (no prompt)"
  disable_updates
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate ENABLE (no prompt)"
  enable_updates
  exit 0
fi

# Interactive
show_status

if prompt_yes_no "Disable system & App Store background updates?" ; then
  disable_updates
else
  enable_updates
fi

hr
say "FINAL STATUS"
show_status
say "Done."

