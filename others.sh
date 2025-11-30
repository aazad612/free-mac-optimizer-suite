#!/bin/zsh

# others.sh
#
# "Other Apple crap" controller – aggressive but non-overlapping with:
#   - siri.sh
#   - animation.sh
#   - spotlight.sh
#   - icloud.sh
#   - media_analysis.sh
#   - telemetry.sh
#   - updates.sh
#
# This targets:
#   - sharingd      → AirDrop / Handoff / Instant Hotspot / shared computers
#   - Maps push     → mapspushd, Maps.pushdaemon
#   - Game Center   → gamed
#   - Family / parental cloud stuff
#   - Safari cloud / history push / webdav sync / notifications
#   - Remote Desktop / screen sharing agents
#   - User notification center agents
#   - AirPlay / AirPort menu helpers
#   - A few low-level network/remote daemons (netbiosd, awacsd, rpmuxd)
#
# It does NOT touch Siri prefs, Spotlight, iCloud core, telemetry, updates,
# photoanalysis, or your visual effects – those are in other scripts.
#
# Usage:
#   ./others.sh           → show status, then prompt: Disable or Enable
#   ./others.sh -disable  → immediately disable all targets (no prompt)
#   ./others.sh -enable   → immediately enable all targets (no prompt)
#
# Everything is verbose. No output is hidden.

###############################################################################
# Helpers
###############################################################################

hr()  { printf '%s\n' "------------------------------------------------------------"; }
say() { printf '%s\n' "$*"; }

cmd() {
  echo "+ $*"
  eval "$*"
  echo
}

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
# Targets (labels only – no files moved/removed)
###############################################################################

# LaunchAgents – user-level “helpers”
AGENT_LABELS=(
  # AirPlay / AirPort helpers
  "com.apple.AirPlayUIAgent"
  "com.apple.AirPortBaseStationAgent"

  # Sharing / Handoff / AirDrop / Instant Hotspot (daemon itself is sharingd)
  # (Note: iCloud/Handoff prefs are handled in icloud.sh; here we only hit the agent.)
  "com.apple.sharingd"

  # Maps background push
  "com.apple.Maps.mapspushd"
  "com.apple.Maps.pushdaemon"

  # Safari cloud / sync / notifications
  "com.apple.SafariCloudHistoryPushAgent"
  "com.apple.safaridavclient"
  "com.apple.SafariNotificationAgent"

  # Game Center
  "com.apple.gamed"

  # Family / parental / cloud family stuff
  "com.apple.familycircled"
  "com.apple.familynotificationd"
  "com.apple.cloudfamilyrestrictionsd-mac"

  # Address Book background sync
  "com.apple.AddressBook.SourceSync"
  "com.apple.AddressBook.abd"

  # iTunes helper launcher
  "com.apple.iTunesHelper.launcher"

  # Remote Desktop / screen sharing extras
  "com.apple.RemoteDesktop"
  "com.apple.screensharing.MessagesAgent"
  "com.apple.screensharing.agent"

  # Notification center agents (user + loginwindow)
  "com.apple.UserNotificationCenterAgent"
  "com.apple.UserNotificationCenterAgent-LoginWindow"

  # Bookstore / Apple Books
  "com.apple.bookstoreagent"

  # Misc UI helpers
  "com.apple.ZoomWindow"
  "com.apple.helpd"

  # Social push
  "com.apple.SocialPushAgent"

  # rtc reporting (FaceTime / diagnostics related – *not* covered by telemetry.sh)
  "com.apple.rtcreportingd"
)

# LaunchDaemons – system-level services
DAEMON_LABELS=(
  # Old Windows file sharing / NetBIOS
  "com.apple.netbiosd"

  # Back to My Mac / wide-area connectivity
  "com.apple.awacsd"

  # Remote debugging of iOS devices
  "com.apple.rpmuxd"

  # System-level screen sharing service
  "com.apple.screensharing"
)

###############################################################################
# Status
###############################################################################

show_status() {
  hr
  say "OTHERS.SH — Extra Apple Services Status (Processes Snapshot)"
  hr

  say "[INFO] Showing selected processes that this script targets:"
  cmd "ps axo pid,comm | grep -Ei 'sharingd|mapspushd|Maps.pushdaemon|AirPlayUIAgent|AirPortBaseStationAgent|gamed|bookstoreagent|SafariCloudHistoryPushAgent|safaridavclient|SafariNotificationAgent|UserNotificationCenter|familycircled|familynotificationd|cloudfamilyrestrictionsd|RemoteDesktop|screensharing|netbiosd|awacsd|rpmuxd|SocialPushAgent' | grep -v grep"

  hr
  say "[INFO] LaunchAgent labels we manage:"
  printf '  %s\n' "${AGENT_LABELS[@]}"
  echo
  say "[INFO] LaunchDaemon labels we manage:"
  printf '  %s\n' "${DAEMON_LABELS[@]}"
  echo
  say "[NOTE] Siri, Spotlight, iCloud core, telemetry, updates, media analysis, and animations"
  say "      are *not* touched here – they live in their own scripts."
}

###############################################################################
# Disable
###############################################################################

disable_others() {
  hr
  say "[ACTION] DISABLING extra Apple background services (AGGRESSIVE)"
  hr

  hr
  say "[STEP] Disabling & booting out LaunchAgents (per-user services)"
  hr

  for label in "${AGENT_LABELS[@]}"; do
    say "[AGENT] $label"

    # Disable via launchctl label (GUI session)
    cmd "launchctl disable gui/$UID/$label || echo '  (launchctl disable may warn if label missing)'"

    # Bootout from GUI session (stops if running)
    cmd "launchctl bootout gui/$UID/$label || echo '  (bootout may warn if label not loaded)'"

    # If a plist exists, unload it explicitly
    plist="/System/Library/LaunchAgents/${label}.plist"
    if [[ -f \"$plist\" ]]; then
      cmd "launchctl unload -w '$plist' || echo '  (unload may warn if already unloaded)'"
    else
      say "  [SKIP] No LaunchAgent plist found at $plist"
    fi
    echo
  done

  hr
  say "[STEP] Disabling & booting out LaunchDaemons (system services)"
  hr

  for label in "${DAEMON_LABELS[@]}"; do
    say "[DAEMON] $label"

    # Disable system service
    cmd "sudo launchctl disable system/$label || echo '  (launchctl disable may warn if label missing)'"

    # Bootout system service
    cmd "sudo launchctl bootout system/$label || echo '  (bootout may warn if label not loaded)'"

    plist="/System/Library/LaunchDaemons/${label}.plist"
    if [[ -f \"$plist\" ]]; then
      cmd \"sudo launchctl unload -w '$plist' || echo '  (unload may warn if already unloaded)'"
    else
      say "  [SKIP] No LaunchDaemon plist found at $plist"
    fi
    echo
  done

  hr
  say "[STEP] Killing any remaining target processes (best-effort)"
  hr

  for p in sharingd mapspushd gamed bookstoreagent SafariCloudHistoryPushAgent safaridavclient SafariNotificationAgent familycircled familynotificationd cloudfamilyrestrictionsd-mac RemoteDesktop screensharingd netbiosd awacsd rpmuxd SocialPushAgent; do
    say "[KILL] $p"
    cmd "pgrep $p || echo '  (no running PIDs)'"
    cmd "sudo killall $p 2>&1 || echo '  (killall may warn if nothing running)'"
  done

  hr
  say "[STATUS AFTER DISABLE]"
  show_status
  say "[COMPLETE] Extra Apple background services have been aggressively disabled."
  say "           (AirPlay menu, Game Center, family cloud helpers, Safari cloud/"
  say "            history push, Remote Desktop, some network noise, etc.)"
}

###############################################################################
# Enable
###############################################################################

enable_others() {
  hr
  say "[ACTION] ENABLING extra Apple background services (undo changes)"
  hr

  hr
  say "[STEP] Enabling & loading LaunchAgents"
  hr

  for label in "${AGENT_LABELS[@]}"; do
    say "[AGENT] $label"

    plist="/System/Library/LaunchAgents/${label}.plist"
    if [[ -f \"$plist\" ]]; then
      cmd "launchctl load -w '$plist' || echo '  (load may warn if already loaded)'"
      cmd "launchctl enable gui/$UID/$label || echo '  (enable may warn if already enabled)'"
      cmd "launchctl kickstart -k gui/$UID/$label || echo '  (kickstart may warn if not running yet)'"
    else
      say "  [SKIP] No LaunchAgent plist found at $plist"
    fi
    echo
  done

  hr
  say "[STEP] Enabling & loading LaunchDaemons"
  hr

  for label in "${DAEMON_LABELS[@]}"; do
    say "[DAEMON] $label"

    plist="/System/Library/LaunchDaemons/${label}.plist"
    if [[ -f \"$plist\" ]]; then
      cmd "sudo launchctl load -w '$plist' || echo '  (load may warn if already loaded)'"
      cmd "sudo launchctl enable system/$label || echo '  (enable may warn if already enabled)'"
      cmd "sudo launchctl kickstart -k system/$label || echo '  (kickstart may warn if not running yet)'"
    else
      say "  [SKIP] No LaunchDaemon plist found at $plist"
    fi
    echo
  done

  hr
  say "[STATUS AFTER ENABLE]"
  show_status
  say "[COMPLETE] Extra Apple background services have been re-enabled"
  say "           (for the labels this script manages)."
}

###############################################################################
# MAIN
###############################################################################

clear
say "============================================================"
say "          OTHERS.SH — Extra Apple Services (Aggressive)"
say "============================================================"
say

if [[ "$1" == "-disable" ]]; then
  say "[MODE] Immediate DISABLE (no prompt)"
  disable_others
  exit 0
fi

if [[ "$1" == "-enable" ]]; then
  say "[MODE] Immediate ENABLE (no prompt)"
  enable_others
  exit 0
fi

# Default: show status + prompt
show_status
echo
if prompt_yes_no "Disable these extra Apple background services now?"; then
  disable_others
else
  enable_others
fi

