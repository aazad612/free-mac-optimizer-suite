#!/bin/zsh

# visual_effects_tuner_verbose.sh
#
# Fully verbose visual effects tuner:
#   - No output suppression
#   - Shows every command and every change
#   - Perfect for transparency/debugging

###############################################################################
# Pretty printing helpers
###############################################################################

hr()  { printf '%s\n' "------------------------------------------------------------"; }
say() { printf '%s\n' "$*"; }
cmd() { echo "+ $*"; eval "$*"; echo; }   # prints & executes visibly

prompt_yes_no() {
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
    [[ -z "$answer" ]] && answer="$default"

    case "$answer" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     say "[WARN] Please type yes or no." ;;
    esac
  done
}

###############################################################################
# Pref helpers — NO /dev/null
###############################################################################

read_pref_bool()   { cmd "defaults read \"$1\" \"$2\""; }
read_pref_float()  { cmd "defaults read \"$1\" \"$2\""; }

detect_pref() {
  # wrapper that returns result (but shows command)
  local out
  out=$(defaults read "$1" "$2" 2>&1)
  echo "$out"
}

get_wallpaper_path() {
  cmd "osascript -e 'tell application \"System Events\" to get picture of current desktop'"
}

screensaver_idle() {
  cmd "defaults -currentHost read com.apple.screensaver idleTime"
}

###############################################################################
# YES/NO translators
###############################################################################

yes_no_value() {
  case "$1" in
    1|true)  echo "Yes" ;;
    0|false) echo "No" ;;
    *)       echo "No" ;;
  esac
}

yes_no_float() {
  if [[ "$1" == "0" ]]; then
    echo "No"
  else
    echo "Yes"
  fi
}

wallpaper_type() {
  local wp="$1"
  if [[ "$wp" == *"Solid Colors/"* ]]; then
    echo "Static (low cost)"
  elif [[ "$wp" == *.heic ]]; then
    echo "Dynamic (higher cost)"
  else
    echo "Static"
  fi
}

###############################################################################
# STATUS PRINTER
###############################################################################

print_visual_status() {
  hr
  say "Visual Effects — Current Status (Verbose)"
  hr

  say "[INFO] Reading accessibility settings…"
  rm=$(detect_pref com.apple.universalaccess reduceMotion)
  rt=$(detect_pref com.apple.universalaccess reduceTransparency)
  diff=$(detect_pref com.apple.Accessibility DifferentiateWithoutColor)

  say "[INFO] Reading Dock animation settings…"
  dock_launch=$(detect_pref com.apple.dock launchanim)
  magnify=$(detect_pref com.apple.dock magnification)
  expose=$(detect_pref com.apple.dock expose-animation-duration)
  ah_delay=$(detect_pref com.apple.dock autohide-delay)
  ah_time=$(detect_pref com.apple.dock autohide-time-modifier)

  say "[INFO] Reading wallpaper…"
  wp=$(get_wallpaper_path)

  say "[INFO] Reading screensaver…"
  ss=$(screensaver_idle)

  say
  say "Accessibility:"
  say "  Reduce Motion:        $(yes_no_value "$rm")"
  say "  Reduce Transparency:  $(yes_no_value "$rt")"
  say "  High Contrast:        $(yes_no_value "$diff")"
  echo

  say "Animations:"
  say "  Dock launch anim:     $(yes_no_value "$dock_launch")"
  say "  Dock magnification:   $(yes_no_value "$magnify")"
  say "  Mission Control anim: $(yes_no_float "$expose")"
  say "  Autohide delay:       $(yes_no_float "$ah_delay")"
  say "  Autohide speed:       $(yes_no_float "$ah_time")"
  echo

  say "Wallpaper:"
  say "  Path: $wp"
  say "  Type: $(wallpaper_type "$wp")"
  echo

  say "Screensaver:"
  say "  Enabled: $(yes_no_float "$ss")"
  echo
}

###############################################################################
# APPLY SETTINGS — FULL VERBOSE MODE
###############################################################################

apply_visual_tweaks() {
  hr
  say "Applying visual performance tweaks (Verbose)…"
  hr

  # Accessibility
  cmd "defaults write com.apple.universalaccess reduceMotion -int 1"
  cmd "defaults write com.apple.universalaccess reduceTransparency -int 1"
  cmd "defaults write com.apple.Accessibility DifferentiateWithoutColor -int 1"

  # Dock
  cmd "defaults write com.apple.dock launchanim -bool false"
  cmd "defaults write com.apple.dock magnification -bool false"
  cmd "defaults write com.apple.dock expose-animation-duration -float 0.1"
  cmd "defaults write com.apple.dock autohide-delay -float 0"
  cmd "defaults write com.apple.dock autohide-time-modifier -float 0.15"

  # Screensaver
  cmd "defaults write com.apple.screensaver idleTime -int 0"
  cmd "defaults -currentHost write com.apple.screensaver idleTime -int 0"

  # Wallpaper

  # Example: run in your shell to download a Sequoia-style wallpaper
  curl -L "https://cdn.osxdaily.com/wp-content/uploads/2025/08/macos-sequoia-default-wallpaper.jpg" \
       -o "$HOME/Pictures/sequoia-default-wallpaper.jpg"

  static_wp="/System/Library/Desktop\ Pictures/Solid\ Colors/Stone.png"
  say "[INFO] Setting wallpaper to Solid Color (Stone)…"
  osascript -e 'tell application "System Events" to tell every desktop to set picture to POSIX file "'"$HOME"'/Pictures/sequoia-default-wallpaper.jpg"'


  # Restart dock + UI
  say "[INFO] Restarting Dock & SystemUIServer…"
  cmd "killall Dock"
  cmd "killall SystemUIServer"

  say "All visual tweaks applied."
  echo
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "   Visual Effects Tuner (Full Verbose Version)"
say "============================================================"
say
print_visual_status

if prompt_yes_no "Disable animations/transparency/dynamic wallpaper?" "yes"; then
  apply_visual_tweaks
else
  say "No changes made."
  exit 0
fi

hr
say "FINAL STATUS:"
hr
print_visual_status
say "Done."

