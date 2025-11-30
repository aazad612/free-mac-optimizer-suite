#!/bin/zsh

# animation.sh
#
# Visual effects controller for macOS:
#   - DOES NOT touch accessibility (Reduce Motion / Transparency).
#   - "Disable" turns off most animations, speeds up Dock, disables screensaver,
#     and sets a static Sequoia wallpaper (downloaded via curl).
#   - "Enable" reverts ONLY what this script changed (Dock + screensaver),
#     leaving the wallpaper as static until the user changes it.
#
# Modes:
#   ./animation.sh           → interactive: "Disable visual effects? [Y/n]"
#   ./animation.sh -disable  → disable immediately (no prompt)
#   ./animation.sh -enable   → enable immediately (no prompt)
#
# Fully verbose, no /dev/null, nothing hidden.

###############################################################################
# CONFIG
###############################################################################

WALLPAPER_URL="https://cdn.osxdaily.com/wp-content/uploads/2024/08/Sequoia-Sunrise-wallpaper-macos.jpg"
WALLPAPER_DIR="$HOME/Pictures/free-mac-optimizer-wallpapers"
WALLPAPER_FILE="$WALLPAPER_DIR/sequoia-static-wallpaper.jpg"

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

yes_no_numeric_nonzero() {
  if [[ "$1" == "0" ]]; then
    echo "No"
  else
    echo "Yes"
  fi
}

wallpaper_type() {
  local wp="$1"
  if echo "$wp" | grep -qi ".heic"; then
    echo "Dynamic/HEIC"
  else
    echo "Static"
  fi
}

get_wallpaper_path() {
  echo "+ osascript -e 'tell application \"System Events\" to get picture of current desktop'"
  osascript -e 'tell application "System Events" to get picture of current desktop'
}

get_screensaver_idle() {
  echo "+ defaults -currentHost read com.apple.screensaver idleTime"
  defaults -currentHost read com.apple.screensaver idleTime 2>&1
}

###############################################################################
# STATUS
###############################################################################

show_status() {
  hr
  say "Visual Effects — Current Status (Verbose)"
  hr

  say "[INFO] Accessibility settings (we DO NOT change these):"
  rm=$(read_pref com.apple.universalaccess reduceMotion)
  rt=$(read_pref com.apple.universalaccess reduceTransparency)
  echo
  say "  Reduce Motion:       $(yes_no_bool "$rm")"
  say "  Reduce Transparency: $(yes_no_bool "$rt")"
  echo

  say "[INFO] Dock animation & speed:"
  launch=$(read_pref com.apple.dock launchanim)
  mag=$(read_pref com.apple.dock magnification)
  expdur=$(read_pref com.apple.dock expose-animation-duration)
  ahdelay=$(read_pref com.apple.dock autohide-delay)
  ahtime=$(read_pref com.apple.dock autohide-time-modifier)
  echo
  say "  Dock launch animation: $(yes_no_bool "$launch")"
  say "  Dock magnification:     $(yes_no_bool "$mag")"
  say "  Mission Control anim:   $(yes_no_numeric_nonzero "$expdur")"
  say "  Dock autohide delay>0:  $(yes_no_numeric_nonzero "$ahdelay")"
  say "  Dock autohide slow:     $(yes_no_numeric_nonzero "$ahtime")"
  echo

  say "[INFO] Screensaver idle time:"
  ssidle=$(get_screensaver_idle)
  echo "  Raw idleTime: $ssidle"
  echo

  say "[INFO] Wallpaper:"
  wp=$(get_wallpaper_path)
  echo "  Path: $wp"
  echo "  Type: $(wallpaper_type "$wp")"
  echo
}

###############################################################################
# DISABLE: turn off animations, speed Dock, kill screensaver, set static wallpaper
###############################################################################

disable_visual_effects() {
  hr
  say "[ACTION] DISABLING visual effects (NOT touching accessibility)"
  hr

  say "[STEP] Dock/window animation tuning"
  cmd "defaults write com.apple.dock launchanim -bool false"
  cmd "defaults write com.apple.dock magnification -bool false"
  cmd "defaults write com.apple.dock expose-animation-duration -float 0.1"
  cmd "defaults write com.apple.dock autohide-delay -float 0"
  cmd "defaults write com.apple.dock autohide-time-modifier -float 0.15"

  say "[STEP] Turning off screensaver (idleTime = 0)"
  cmd "defaults write com.apple.screensaver idleTime -int 0"
  cmd "defaults -currentHost write com.apple.screensaver idleTime -int 0"

  hr
  say "[STEP] Downloading static macOS Sequoia wallpaper (always, no optional shit)"
  hr
  say "[INFO] Wallpaper URL: $WALLPAPER_URL"
  say "[INFO] Target dir:    $WALLPAPER_DIR"
  say "[INFO] Target file:   $WALLPAPER_FILE"
  cmd "mkdir -p \"$WALLPAPER_DIR\""
  cmd "curl -L \"$WALLPAPER_URL\" -o \"$WALLPAPER_FILE\""
  say "[INFO] Downloaded file:"
  cmd "ls -l \"$WALLPAPER_FILE\""

  if [[ ! -s "$WALLPAPER_FILE" ]]; then
    say "[ERROR] Wallpaper file is missing or empty. NOT changing wallpaper."
  else
    hr
    say "[STEP] Applying static Sequoia wallpaper to ALL desktops/spaces"
    hr
    say "[INFO] AppleScript to be executed:"
    cat <<EOF
tell application "System Events"
  repeat with d in desktops
    set picture of d to POSIX file "$WALLPAPER_FILE"
  end repeat
end tell
EOF
    echo

    osascript <<EOF
tell application "System Events"
  repeat with d in desktops
    set picture of d to POSIX file "$WALLPAPER_FILE"
  end repeat
end tell
EOF
  fi

  hr
  say "[STEP] Restarting Dock & SystemUIServer to apply changes"
  hr
  cmd "killall Dock"
  cmd "killall SystemUIServer"

  say "[COMPLETE] Visual effects disabled (accessibility untouched, wallpaper static)."
}

###############################################################################
# ENABLE: restore what we changed (Dock + screensaver), LEAVE wallpaper static
###############################################################################

enable_visual_effects() {
  hr
  say "[ACTION] ENABLING visual effects (reverting ONLY what this script changed)"
  hr

  say "[STEP] Restoring Dock animation behavior"
  cmd "defaults write com.apple.dock launchanim -bool true"
  cmd "defaults write com.apple.dock magnification -bool false"

  # Delete custom timing keys so macOS uses its defaults again
  cmd "defaults delete com.apple.dock expose-animation-duration"
  cmd "defaults delete com.apple.dock autohide-delay"
  cmd "defaults delete com.apple.dock autohide-time-modifier"

  say "[STEP] Restoring screensaver idleTime to 10 minutes (600s)"
  cmd "defaults write com.apple.screensaver idleTime -int 600"
  cmd "defaults -currentHost write com.apple.screensaver idleTime -int 600"

  # DO NOT touch wallpaper here. User keeps the static Sequoia until they change it.

  hr
  say "[STEP] Restarting Dock & SystemUIServer"
  hr
  cmd "killall Dock"
  cmd "killall SystemUIServer"

  say "[COMPLETE] Visual effects restored (Dock/screensaver). Wallpaper left static."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "   Visual Effects / Animation Controller (Verbose, Flags)"
say "============================================================"
say

# Flag mode
if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate disable (no prompt)"
  disable_visual_effects
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate enable (no prompt)"
  enable_visual_effects
  hr
  say "FINAL STATUS"
  show_status
  exit 0
fi

# Interactive mode
show_status

if prompt_yes_no "Disable visual effects (animations/screensaver) and set static Sequoia wallpaper?" ; then
  disable_visual_effects
else
  enable_visual_effects
fi

hr
say "FINAL STATUS"
show_status
say "Done."

