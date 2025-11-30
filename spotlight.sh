#!/bin/zsh

# spotlight.sh
#
# Spotlight / Search noise controller for macOS:
#   - Controls Spotlight indexing (mds, mdworker, etc.)
#   - Disables/enables Spotlight Suggestions & Safari search suggestions.
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
  # When SuggestionsDisabled = 1 → suggestions OFF
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
# DISABLE: Stop indexing & online suggestions
###############################################################################

disable_spotlight() {
  hr
  say "[ACTION] DISABLING Spotlight indexing and online search suggestions"
  hr

  say "[STEP] Turning OFF indexing for / (root volume)"
  cmd "mdutil -i off /"

  # You could add other volumes here if you want:
  # cmd "mdutil -i off /Volumes/Data"

  echo
  say "[STEP] Disabling Spotlight Suggestions"
  # 1 = disabled
  cmd "defaults write com.apple.Spotlight SuggestionsDisabled -bool true"

  echo
  say "[STEP] Hardening Safari search (no online suggestions)"
  # Safari: don't send typed queries to Apple
  cmd "defaults write com.apple.Safari UniversalSearchEnabled -bool false"
  cmd "defaults write com.apple.Safari SuppressSearchSuggestions -bool true"

  hr
  say "[STEP] Showing Spotlight status AFTER disable"
  hr
  cmd "mdutil -s /"
  cmd "ps axo pid,comm | grep -Ei 'mds|mdworker|mdwrite|spotlight|corespotlight|suggest' | grep -v grep"

  say "[COMPLETE] Spotlight indexing + online suggestions disabled (Safari + system)."
}

###############################################################################
# ENABLE: Restore indexing & suggestions
###############################################################################

enable_spotlight() {
  hr
  say "[ACTION] ENABLING Spotlight indexing and online search suggestions"
  hr

  say "[STEP] Turning ON indexing for / (root volume)"
  cmd "mdutil -i on /"

  echo
  say "[STEP] Enabling Spotlight Suggestions (system)"
  # 0 = enabled
  cmd "defaults write com.apple.Spotlight SuggestionsDisabled -bool false"

  echo
  say "[STEP] Relaxing Safari search (allow Apple suggestions again)"
  cmd "defaults write com.apple.Safari UniversalSearchEnabled -bool true"
  cmd "defaults write com.apple.Safari SuppressSearchSuggestions -bool false"

  hr
  say "[STEP] Showing Spotlight status AFTER enable"
  hr
  cmd "mdutil -s /"
  cmd "ps axo pid,comm | grep -Ei 'mds|mdworker|mdwrite|spotlight|corespotlight|suggest' | grep -v grep"

  say "[COMPLETE] Spotlight indexing + online suggestions enabled."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "   Spotlight / Search Noise Controller (Verbose, Flags)"
say "============================================================"
say

# Flag mode
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate disable (no prompt)"
  disable_spotlight
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate enable (no prompt)"
  enable_spotlight
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

# Interactive mode
show_status

if prompt_yes_no "Disable Spotlight indexing and online search suggestions (system + Safari)?" ; then
  disable_spotlight
else
  enable_spotlight
fi

hr
say "FINAL STATUS"
show_status
say "Done."

