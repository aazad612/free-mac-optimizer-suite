#!/bin/zsh

# media_analysis.sh
#
# Photos / media analysis controller for macOS:
#   - Targets photoanalysisd, photolibraryd, mediaanalysisd, etc.
#   - Aims to stop background face/object/video analysis that eats CPU.
#
# Modes:
#   ./media_analysis.sh           → interactive prompt
#   ./media_analysis.sh -disable  → disable immediately (no prompt)
#   ./media_analysis.sh -enable   → enable immediately (no prompt)
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

###############################################################################
# STATUS
###############################################################################

show_status() {
  hr
  say "Photos / Media Analysis — Current Status (Verbose)"
  hr

  say "[INFO] Media/Photos analysis related processes:"
  cmd "ps axo pid,comm | grep -Ei 'photoanalysisd|photolibraryd|mediaanalysisd|VTDecoderXPCService|mediaremoted|media|Photos' | grep -v grep"
}

###############################################################################
# DISABLE: Stop media analysis daemons (best-effort)
###############################################################################

disable_media_analysis() {
  hr
  say "[ACTION] DISABLING Photos / media analysis daemons"
  hr

  hr
  say "[STEP] Unloading media-analysis related LaunchDaemons (best-effort)"
  hr

  MEDIA_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.photoanalysisd.plist"
    "/System/Library/LaunchDaemons/com.apple.photolibraryd.plist"
    "/System/Library/LaunchDaemons/com.apple.mediaanalysisd.plist"
  )

  for d in "${MEDIA_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[UNLOAD] $d"
      cmd "sudo launchctl unload -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  hr
  say "[STEP] Unloading media-analysis LaunchAgents (GUI, best-effort)"
  hr

  MEDIA_AGENTS=(
    "/System/Library/LaunchAgents/com.apple.photoanalysisd.plist"
    "/System/Library/LaunchAgents/com.apple.photolibraryd.plist"
    "/System/Library/LaunchAgents/com.apple.mediaanalysisd.plist"
  )

  for a in "${MEDIA_AGENTS[@]}"; do
    if [[ -f "$a" ]]; then
      say "[UNLOAD] $a"
      cmd "launchctl unload -w '$a'"
    else
      say "[SKIP] Not found: $a"
    fi
  done

  hr
  say "[STEP] Killing media analysis processes"
  hr

  for p in photoanalysisd photolibraryd mediaanalysisd VTDecoderXPCService mediaremoted; do
    say "[KILL] $p"
    cmd "pgrep $p"
    cmd "killall $p"
  done

  hr
  say "[STEP] Status AFTER disable:"
  hr
  show_status
  say "[NOTE] Some daemons may come back when you open Photos or similar apps."
  say "      But in the background, analysis should be heavily reduced."
  say "[COMPLETE] Media analysis disabled as much as userland can manage."
}

###############################################################################
# ENABLE: Restore media analysis daemons we touched
###############################################################################

enable_media_analysis() {
  hr
  say "[ACTION] ENABLING Photos / media analysis daemons (undoing our changes)"
  hr

  hr
  say "[STEP] Loading media-analysis LaunchDaemons (best-effort)"
  hr

  MEDIA_DAEMONS=(
    "/System/Library/LaunchDaemons/com.apple.photoanalysisd.plist"
    "/System/Library/LaunchDaemons/com.apple.photolibraryd.plist"
    "/System/Library/LaunchDaemons/com.apple.mediaanalysisd.plist"
  )

  for d in "${MEDIA_DAEMONS[@]}"; do
    if [[ -f "$d" ]]; then
      say "[LOAD] $d"
      cmd "sudo launchctl load -w '$d'"
    else
      say "[SKIP] Not found: $d"
    fi
  done

  hr
  say "[STEP] Loading media-analysis LaunchAgents (GUI, best-effort)"
  hr

  MEDIA_AGENTS=(
    "/System/Library/LaunchAgents/com.apple.photoanalysisd.plist"
    "/System/Library/LaunchAgents/com.apple.photolibraryd.plist"
    "/System/Library/LaunchAgents/com.apple.mediaanalysisd.plist"
  )

  for a in "${MEDIA_AGENTS[@]}"; do
    if [[ -f "$a" ]]; then
      say "[LOAD] $a"
      cmd "launchctl load -w '$a'"
    else
      say "[SKIP] Not found: $a"
    fi
  done

  hr
  say "[STEP] Status AFTER enable:"
  hr
  show_status
  say "[COMPLETE] Media analysis restored (to whatever macOS considers stock)."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "  Photos / Media Analysis Controller (Verbose, Flags)"
say "============================================================"
say

# Flag mode
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate DISABLE (no prompt)"
  disable_media_analysis
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate ENABLE (no prompt)"
  enable_media_analysis
  exit 0
fi

# Interactive mode
show_status

if prompt_yes_no "Disable Photos / media analysis daemons (photoanalysisd, photolibraryd, mediaanalysisd, etc.)?" ; then
  disable_media_analysis
else
  enable_media_analysis
fi

hr
say "FINAL STATUS"
show_status
say "Done."

