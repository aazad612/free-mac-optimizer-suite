#!/bin/zsh

# spotlight.sh
#
# Spotlight / Search noise controller for macOS:
#   - Controls Spotlight indexing (mds, mdworker, etc.)
#   - Disables/enables Spotlight Suggestions & Safari search suggestions.
#   - More aggressive: unloads Spotlight launchd jobs and killalls daemons.
#
# Modes:
#   ./spotlight.sh           → interactive prompt
#   ./spotlight.sh -disable  → disable immediately (no prompt)
#   ./spotlight.sh -enable   → enable immediately (no prompt)
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
  say "Spotlight / Search — Current Status (Verbose)"
  hr

  say "[INFO] Spotlight indexing status for root volume (/):"
  cmd "mdutil -s /"

  echo
  say "[INFO] Spotlight Suggestions (system-wide):"
  sugg=$(read_pref com.apple.Spotlight SuggestionsDisabled)
  echo
  say "  Spotlight suggestions disabled: $(yes_no_bool "$sugg")"
  echo

  say "[INFO] Safari search suggestion settings:"
  us=$(read_pref com.apple.Safari UniversalSearchEnabled)
  ss=$(read_pref com.apple.Safari SuppressSearchSuggestions)
  echo
  say "  Safari UniversalSearchEnabled (online suggestions allowed): $(yes_no_bool "$us")"
  say "  Safari SuppressSearchSuggestions (suppress = Yes):           $(yes_no_bool "$ss")"
  echo

  say "[INFO] Spotlight / indexing related processes:"
  cmd "ps axo pid,comm | grep -Ei 'mds|mdworker|mdwrite|spotlight|corespotlight|suggest' | grep -v grep"
}

###############################################################################
# DISABLE: Stop indexing & online suggestions, unload & kill daemons
###############################################################################

disable_spotlight() {
  hr
  say "[ACTION] DISABLING Spotlight indexing and online search suggestions (AGGRESSIVE)"
  hr

  say "[STEP] Turning OFF indexing for / (root volume)"
  cmd "mdutil -i off /"

  echo
  say "[STEP] Disabling Spotlight Suggestions (system)"
  cmd "defaults write com.apple.Spotlight SuggestionsDisabled -bool true"

  echo
  say "[STEP] Hardening Safari search (no online suggestions)"
  cmd "defaults write com.apple.Safari UniversalSearchEnabled -bool false"
  cmd "defaults write com.apple.Safari SuppressSearchSuggestions -bool true"

  echo
  hr
  say "[STEP] Unloading Spotlight / metadata launchd jobs (best-effort)"
  hr

  # These plist names may vary slightly by macOS version. If a file doesn't exist,
  # you'll see the error – we are not hiding anything.
  SPOTLIGHT_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.plist"
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.scan.plist"
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.spindump.plist"
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.index.plist"
  )

  SPOTLIGHT_AGENTS=(
    "/System/Library/LaunchAgents/com.apple.Spotlight.plist"
    "/System/Library/LaunchAgents/com.apple.corespotlightd.plist"
  )

  say "[INFO] LaunchDaemons:"
  for d in "${SPOTLIGHT_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[UNLOAD] $d"
      cmd "sudo launchctl unload -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  echo
  say "[INFO] LaunchAgents (current user GUI):"
  for a in "${SPOTLIGHT_AGENTS[@]}"; do
    if [[ -f "$a" ]]; then
      say "[UNLOAD] $a"
      cmd "launchctl unload -w '$a'"
    else
      say "[SKIP] Not found: $a"
    fi
  done

  echo
  hr
  say "[STEP] Killing Spotlight / metadata daemons"
  hr

  for p in mds mds_stores mds_scan mds_spindump mds_index mdworker mdworker_shared mdwrite \
           corespotlightd spotlightknowledged suggestd Spotlight; do
    say "[KILL] $p"
    cmd "pgrep $p"
    cmd "killall $p"
  done

  hr
  say "[STEP] Spotlight status AFTER disable:"
  hr
  cmd "mdutil -s /"
  cmd "ps axo pid,comm | grep -Ei 'mds|mdworker|mdwrite|spotlight|corespotlight|suggest' | grep -v grep"

  say "[NOTE] Some system processes may respawn because macOS really wants Spotlight alive."
  say "      But indexing is OFF and suggestions are OFF; CPU/network impact should be much lower."
  say "[COMPLETE] Spotlight indexing + online suggestions disabled as aggressively as we can."
}

###############################################################################
# ENABLE: Restore indexing & suggestions, reload daemons
###############################################################################

enable_spotlight() {
  hr
  say "[ACTION] ENABLING Spotlight indexing and online search suggestions"
  hr

  say "[STEP] Turning ON indexing for / (root volume)"
  cmd "mdutil -i on /"

  echo
  say "[STEP] Enabling Spotlight Suggestions (system)"
  cmd "defaults write com.apple.Spotlight SuggestionsDisabled -bool false"

  echo
  say "[STEP] Relaxing Safari search (allow Apple suggestions again)"
  cmd "defaults write com.apple.Safari UniversalSearchEnabled -bool true"
  cmd "defaults write com.apple.Safari SuppressSearchSuggestions -bool false"

  echo
  hr
  say "[STEP] Reloading Spotlight / metadata launchd jobs (best-effort)"
  hr

  SPOTLIGHT_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.plist"
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.scan.plist"
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.spindump.plist"
    "/System/Library/LaunchDaemons/com.apple.metadata.mds.index.plist"
  )

  SPOTLIGHT_AGENTS=(
    "/System/Library/LaunchAgents/com.apple.Spotlight.plist"
    "/System/Library/LaunchAgents/com.apple.corespotlightd.plist"
  )

  say "[INFO] LaunchDaemons:"
  for d in "${SPOTLIGHT_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[LOAD] $d"
      cmd "sudo launchctl load -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  echo
  say "[INFO] LaunchAgents (current user GUI):"
  for a in "${SPOTLIGHT_AGENTS[@]}"; do
    if [[ -f "$a" ]]; then
      say "[LOAD] $a"
      cmd "launchctl load -w '$a'"
    else
      say "[SKIP] Not found: $a"
    fi
  done

  hr
  say "[STEP] Spotlight status AFTER enable:"
  hr
  cmd "mdutil -s /"
  cmd "ps axo pid,comm | grep -Ei 'mds|mdworker|mdwrite|spotlight|corespotlight|suggest' | grep -v grep"

  say "[COMPLETE] Spotlight indexing + online suggestions enabled (or as close as macOS allows)."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "   Spotlight / Search Noise Controller (Verbose, Aggressive)"
say "============================================================"
say

# Flag mode
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate DISABLE (no prompt)"
  disable_spotlight
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate ENABLE (no prompt)"
  enable_spotlight
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

# Interactive mode
show_status

if prompt_yes_no "Disable Spotlight indexing and online search suggestions (and unload/kill daemons)?" ; then
  disable_spotlight
else
  enable_spotlight
fi

hr
say "FINAL STATUS"
show_status
say "Done."

