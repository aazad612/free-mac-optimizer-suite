# free-mac-optimizer-suite — Process Reference

This document explains **what each script targets** and **what every major process / service does** in the `free-mac-optimizer-suite` you’re using.

> ⚠️ **Important**
> - Everything here is *best-effort documentation* based on Apple’s usual naming and behavior.
> - Apple changes internals between macOS versions; some labels or behaviors may differ slightly on Sequoia versus older releases.
> - All of your scripts are designed to be **reversible**: each has a matching `-enable` mode to undo what was changed.

The scripts covered here:

- `siri.sh` / `siri_ai_control.sh`
- `animation.sh`
- `spotlight.sh`
- `telemetry.sh`
- `updates.sh`
- `suggestions.sh`
- `media_analysis.sh`
- `others.sh`


---

## 1. `siri.sh` / `siri_ai_control.sh` — Siri & Apple Intelligence

### What this script does

- Toggles **Siri** and **Apple Intelligence** features on/off.
- Controls:
  - Voice assistant (Siri UI, “Hey Siri” wake word)
  - Apple Intelligence cloud + inline suggestions
  - Backing daemons that implement Siri & AI features

### Key processes / services

#### `assistantd`
- Core **Siri assistant daemon**.
- Handles Siri’s main logic and communication when you talk to Siri.
- Disabling it prevents Siri from running or responding.

#### `siriknowledged`
- Siri’s **knowledge daemon**.
- Handles knowledge lookup, answers, and context for Siri queries.

#### `siriinferenced`
- **Siri inference daemon**.
- Runs on-device machine learning models for Siri / AI features.

#### `sirittsd`
- Siri **text-to-speech daemon**.
- Responsible for Siri’s voice output.

#### `intelligenceplatformd`
- Core **Apple Intelligence platform daemon**.
- Coordinates AI features such as on-device intelligence, summaries, and smart responses.

#### `naturallanguaged`
- System **natural language processing** daemon.
- Used for language understanding, suggestions, and some system-level NLP features.

#### `biomed`
- Part of the **Biome streams / data system**.
- Handles certain behavioral or contextual data used by Apple’s intelligence features.

### Effects of disabling

- Siri won’t respond or show the Siri UI.
- “Hey Siri” voice activation stops.
- Apple Intelligence and inline AI suggestions are turned off.
- Related background CPU/memory use drops.
- Some system suggestion behaviors may reduce or disappear.

Re-enable via: `./siri.sh -enable` (or the equivalent new controller script).

---

## 2. `animation.sh` — Visual Effects & Wallpaper

### What this script does

- **Does NOT disable a process directly**, but changes preferences that affect:
  - Dock animations and launch effects
  - Mission Control animation speed
  - Dock auto-hide delay & speed
  - Screensaver idle time
  - System wallpaper: forces a **static Sequoia JPEG** instead of dynamic HEIC

### Key settings (not processes)

- `com.apple.dock`:
  - `launchanim`
  - `magnification`
  - `expose-animation-duration`
  - `autohide-delay`
  - `autohide-time-modifier`
- `com.apple.screensaver`:
  - `idleTime`

Effects:
- Dock and window animations are faster or disabled.
- Screensaver is turned off (idleTime = 0) when disabled.
- Wallpaper becomes static and low-cost to render.
- On enable, Dock and screensaver settings are restored; wallpaper is left static until you change it manually.

---

## 3. `spotlight.sh` — Spotlight & Indexing

### What this script does

- Disables or enables **Spotlight indexing** and related search behavior.
- Aggressively unloads and kills metadata & Spotlight daemons.
- Turns **Spotlight Suggestions** and **Safari search suggestions** off/on.

### Key processes / services

#### `mds`
- **Metadata server**.
- Main engine behind Spotlight indexing.

#### `mds_stores`, `mds_scan`, `mds_spindump`, `mds_index`
- Helper daemons for `mds`:
  - `mds_stores` / `mds_index`: maintain on-disk metadata indexes.
  - `mds_scan`: scans the file system.
  - `mds_spindump`: handles performance snapshots / debugging of mds.

#### `mdworker`, `mdworker_shared`
- Worker processes that actually **scan files** and compute metadata.
- Often show up repeatedly and can use noticeable CPU.

#### `mdwrite`
- Writes metadata information to the Spotlight index.

#### `corespotlightd`
- Daemon that supports **Core Spotlight** APIs (e.g. apps indexing content for system search).

#### `spotlightknowledged`
- Handles Spotlight’s **knowledge-based results**, such as suggestions and smart results.

#### `suggestd`
- Part of **Core Suggestions**.
- Provides suggested contacts, events, and other contextual suggestions.

### Other toggles

- **Spotlight Suggestions** (`com.apple.Spotlight SuggestionsDisabled`)
- **Safari search suggestions** (`com.apple.Safari UniversalSearchEnabled`, `SuppressSearchSuggestions`)

### Effects of disabling

- Indexing for `/` is turned off via `mdutil -i off /`.
- Most Spotlight-related processes are unloaded and killed.
- Online search suggestions and Safari’s sending of typed queries to Apple are disabled.
- Manual file search may still work but with fewer or older results.
- Re-enabling restores indexing and suggestions.

Re-enable via: `./spotlight.sh -enable`.

---

## 4. `telemetry.sh` — Analytics & Diagnostics

### What this script does

- Turns off “Send diagnostics & usage data to Apple” and third-party crash/usage sharing.
- Tries to unload and kill analytics and diagnostics daemons.

### Key processes / services

#### `analyticsd`
- Main **analytics daemon**.
- Collects and sends usage and performance metrics to Apple.

#### `diagnosticd`
- Handles various **diagnostic reports** and logging.

#### `submitdiaginfo`
- Utility used to **submit diagnostic information** to Apple.

#### `spindump`
- Captures **stack traces** and performance snapshots when apps or the system hang.

#### `ReportCrash` / `crashreporterd`
- Crash reporting daemons:
  - Capture crash logs
  - Prepare them for viewing and optional submission to Apple

#### `systemstatsd`
- Collects **system statistics**, power usage, and performance data.

#### `symptomsd`
- Monitors **network and system “symptoms”**, like poor connectivity.

#### `corecaptured`
- Responsible for capturing **low-level system traces** and logs, often for hardware or kernel-level issues.

#### (Possibly) `logd`
- Central logging daemon.
- Your script *looks at it*, but does not try to disable core logging (that would be unsafe).

### Preferences touched

- `/Library/Preferences/com.apple.SubmitDiagInfo`:
  - `AutoSubmit`
  - `ThirdPartyDataSubmit`
- `/Library/Preferences/com.apple.analyticsd`:
  - `AllowMixedDeviceIdentifiers`

### Effects of disabling

- macOS stops *sending* diagnostics & analytics to Apple and third parties.
- Crash reporting and analytics daemons are unloaded where allowed.
- Some processes may still restart (macOS likes having crash plumbing), but actual data submission is heavily reduced.

Re-enable via: `./telemetry.sh -enable`.

---

## 5. `updates.sh` — Software Update & App Store Noise

### What this script does

- Controls **automatic system updates** and **App Store background updates**.
- Disables or enables:
  - Automatic checking for updates
  - Automatic download & install
  - App Store automatic application updates
  - Related daemons & helpers

### Key processes / services

#### `softwareupdate`
- CLI and service for **macOS software updates**.
- When run in background, checks for updates and downloads them.

#### `softwareupdated` (daemon)
- LaunchDaemon that actually performs update operations behind the scenes.

#### `storeassetd`
- Manages **download and installation of assets**, including app updates from the App Store.

#### `installd`
- System **install daemon**.
- Handles installing packages and app bundles.

#### `appstoreagent`
- Background agent for the **Mac App Store**.
- Checks for updates, handles some communications with the App Store UI.

#### `storeaccountd`
- Manages **App Store / Apple ID account** state and authentication.

#### `commerce` (various commerce processes)
- Handles parts of purchasing, in-app purchase plumbing, or App Store commerce flows.

### Preferences / settings

- `softwareupdate --schedule on/off`
- `com.apple.SoftwareUpdate`:
  - `AutomaticCheckEnabled`
  - `AutomaticDownload`
  - `CriticalUpdateInstall`
- `com.apple.commerce`:
  - `AutoUpdate`

### Effects of disabling

- No more automatic system update checks or downloads.
- No automatic app updates from the App Store.
- Reduced background CPU/network activity from update services.
- Manual updates through System Settings / App Store continue to work.

Re-enable via: `./updates.sh -enable`.

---

## 6. `suggestions.sh` — Siri / System Suggestions & Learning

*(Distinct from Siri core and Spotlight; this focuses on **suggestion and learning daemons** and app-learning behavior.)*

### What this script does

- Prevents Siri/system from **“learning from apps”** using a blacklist.
- Disables and boots out suggestion-related launch agents.
- Kills suggestion daemons.

### Key processes / services

#### `knowledge-agent` (label form: `com.apple.knowledge-agent`)
- Manages **on-device knowledge** and learns from user behavior and app usage.

#### `suggestd`
- Core **suggestions daemon** (CoreSuggestions).
- Drives suggestions for people, events, apps, etc.

#### `parsecd`
- Background **context and search / parsing daemon**.
- Used for contact suggestions, addresses, and other structured data extraction.

#### `spotlightknowledged`
- Knowledge component used by Spotlight for suggested results.

#### `biomed`
- Biome-related daemon that handles data streams used for learning and suggestions.

### Preferences / settings

- `com.apple.suggestions`:
  - `SiriCanLearnFromAppBlacklist` (array of app bundle IDs that Siri cannot learn from)
- `com.apple.lookup.shared`:
  - `LookupSuggestionsDisabled`

### Effects of disabling

- Siri/system stop learning from common apps like Mail, Messages, Safari, Calendar, etc.
- Many proactive suggestions and “people you might contact” style features reduce or vanish.
- Suggestion daemons are killed and disabled as much as macOS allows.

Re-enable via: `./suggestions.sh -enable`.

---

## 7. `media_analysis.sh` — Photos & Media Analysis

### What this script does

- Targets **photo & media background analysis** processes used for:
  - Face recognition
  - Scene/object detection
  - Video analysis
  - Photo “memories” and similar features

### Key processes / services

#### `photoanalysisd`
- Main **Photos analysis daemon**.
- Does face detection, scene detection, and other computational photography work in the background.

#### `photolibraryd`
- Manages the **Photos library database** and related background tasks.

#### `mediaanalysisd`
- Handles **media (photo/video) analysis** separate from the Photos app itself.

#### `VTDecoderXPCService`
- Video decoding helper service.
- Used for transcoding or analyzing videos.

#### `mediaremoted`
- Manages shared access to **media playback state** across the system.
- Also used for media key handling; killing it temporarily may affect media control features until it restarts.

### Effects of disabling

- Background face/scene/video analysis on your photo library is drastically reduced or stopped.
- Background CPU usage from Photos on idle should drop.
- When you open Photos, some daemons may restart if the app needs them.

Re-enable via: `./media_analysis.sh -enable`.

---

## 8. `others.sh` — Extra Apple Services (Aggressive, Non-Overlapping)

This script is your **“everything else”** cleaner. It intentionally avoids the subsystems already handled by your other scripts and focuses on extra Apple ecosystem helpers and background services.

### What this script does

- Disables and/or unloads a collection of **extra background services**, including:
  - AirPlay & AirPort UI helpers
  - Sharing/Handoff/AirDrop helper
  - Maps push daemons
  - Safari cloud/history push helpers
  - Game Center
  - Family / parental cloud helpers
  - AddressBook background sync
  - Remote Desktop & screen sharing extras
  - Notification center agents
  - Bookstore / Apple Books background agent
  - Misc UI helpers
  - Social push
  - Some network / remote access daemons

### Key LaunchAgents (user-level)

#### `com.apple.AirPlayUIAgent`
- Handles **AirPlay UI** in the menu bar.

#### `com.apple.AirPortBaseStationAgent`
- Manages **AirPort / Wi-Fi base station** notifications and configuration helpers.

#### `com.apple.sharingd`
- Central daemon for **sharing services**:
  - AirDrop
  - Handoff
  - Instant Hotspot
  - Some shared services in Finder and Messages

#### `com.apple.Maps.mapspushd`, `com.apple.Maps.pushdaemon`
- Handle **Maps-related push notifications and updates**.

#### `com.apple.SafariCloudHistoryPushAgent`
- Syncs **Safari history via iCloud**.

#### `com.apple.safaridavclient`
- Handles **WebDAV / iCloud-style Safari data sync**.

#### `com.apple.SafariNotificationAgent`
- Manages **Safari website notifications**.

#### `com.apple.gamed`
- **Game Center** daemon.
- Manages Game Center sign-in, leaderboards, achievements, game invites, etc.

#### `com.apple.familycircled`, `com.apple.familynotificationd`, `com.apple.cloudfamilyrestrictionsd-mac`
- **Family Sharing / parental controls**-related daemons.

#### `com.apple.AddressBook.SourceSync`, `com.apple.AddressBook.abd`
- Handle **Contacts / Address Book syncing** and background operations.

#### `com.apple.iTunesHelper.launcher`
- Legacy helper for **iTunes / Music** to react to device connections and other triggers.

#### `com.apple.RemoteDesktop`
- Agent related to **Apple Remote Desktop / screen control**.

#### `com.apple.screensharing.MessagesAgent`, `com.apple.screensharing.agent`
- Support **screen sharing**, especially integrated with Messages.

#### `com.apple.UserNotificationCenterAgent`, `com.apple.UserNotificationCenterAgent-LoginWindow`
- User and login-window **notification center agents**; manage delivery of notifications.

#### `com.apple.bookstoreagent`
- Background agent for **Apple Books / Book Store** syncing and downloads.

#### `com.apple.ZoomWindow`
- Helper for Zoomed window UI behavior (not the Zoom app; related to system zoom/window effects).

#### `com.apple.helpd`
- Apple system **Help viewer daemon**.

#### `com.apple.SocialPushAgent`
- Handles **push notifications for social account integrations** (Twitter, etc., in older macOS and some legacy frameworks).

#### `com.apple.rtcreportingd`
- Real-time communication **reporting daemon**, used by FaceTime and similar services for quality/diagnostic reporting.

### Key LaunchDaemons (system-level)

#### `com.apple.netbiosd`
- **NetBIOS daemon**.
- Used for legacy Windows file sharing / network discovery.

#### `com.apple.awacsd`
- **Apple Wide-Area Connectivity daemon** (Back to My Mac-style services in older eras, some network reachability in newer macOS).

#### `com.apple.rpmuxd`
- **Remote multiplexing daemon**, used for debugging or device communication (often with iOS devices).

#### `com.apple.screensharing`
- System **screen sharing service**.

### Effects of disabling

- AirPlay menu and AirPort base station helper behavior may disappear from the menu bar.
- AirDrop/Handoff/Instant Hotspot behaviors may be reduced or disabled (since `sharingd` is targeted).
- Maps won’t receive background push updates.
- Safari cloud/history syncing is reduced; Safari still works, but some iCloud integration may pause.
- Game Center is effectively disabled.
- Family Sharing / parental cloud automations are reduced.
- Contacts background sync might need manual triggers instead of always-on.
- Apple Remote Desktop / screen sharing convenience helpers are cut back.
- Notification center agents may be simplified (though core notification delivery is robust and may restart some agents).
- Books / Bookstore background syncing slows or stops.
- Legacy network discovery daemons (NetBIOS, awacs, rpmuxd) are disabled, reducing background network noise.

Re-enable via: `./others.sh -enable`.

---

## 9. Notes on Overlap & Safety

- **No duplicate targeting**:  
  `others.sh` was built to **avoid** stepping on the responsibilities of:
  - `siri.sh` (Siri/Apple Intelligence core)
  - `animation.sh` (visual effects)
  - `spotlight.sh` (indexing & search daemons)
  - `icloud.sh` (iCloud-specific behaviors)
  - `media_analysis.sh` (photo/video analysis)
  - `telemetry.sh` (analytics/diagnostics)
  - `updates.sh` (system/App Store updates)
  - `suggestions.sh` (learning & suggestion daemons)

- **Reversibility**: every script has `-disable` and `-enable` modes where:
  - `-disable` updates preferences, unloads daemons/agents, and kills processes.
  - `-enable` attempts to restore preferences and reload the same daemons/agents.

- **macOS will revive some things**:
  - Certain system processes (especially crash handling, logging, and some search helpers) may respawn even after being killed or unloaded.
  - That’s expected; the suite aims to **reduce background load and network chatter**, not break core OS integrity.

---

## 10. Recommended Use Order

For a non-technical user running everything for the first time:

1. `siri.sh -disable`  
2. `animation.sh -disable`  
3. `spotlight.sh -disable`  
4. `telemetry.sh -disable`  
5. `updates.sh -disable`  
6. `suggestions.sh -disable`  
7. `media_analysis.sh -disable`  
8. `others.sh -disable`  

Re-enabling is symmetric — use `-enable` on any individual script where you miss a particular feature.

---

If you’re shipping this as part of the **free-mac-optimizer-suite**, this `reference.md` can live at the root of the repo so normal humans (and suspicious IT people) can see exactly **what’s being changed and why**.
