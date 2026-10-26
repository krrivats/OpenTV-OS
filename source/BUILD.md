# Building the apps yourself

The Release zip has the apps ready-built. To build them from source instead:

1. Clone CleanYourTV at the commit these changes start from, and apply them:
   ```bash
   git clone https://github.com/Gathin23/cleanyourtv
   cd cleanyourtv
   git checkout f592b6d
   git apply ../source/opentv-changes.patch
   ```
   The patch has the launcher changes (festival calendar and windows, weather pill and sky, icons, `add_tile`,
   `key_filter_home_only`, `app_labels` over cards), the upgraded Weather add-on and the new `addons/remote-buttons`.
2. Install JDK 17 and the Android SDK (platform 34, build-tools 34.0.0).
3. Build each app, from its folder:
   ```bash
   cd launcher && ./gradlew assembleRelease          # -> OpenTV-Launcher.apk
   cd ../addons/weather && ./gradlew assembleRelease  # -> Weather.apk
   cd ../world-clock && ./gradlew assembleRelease     # -> WorldClock.apk
   cd ../remote-buttons && ./gradlew assembleRelease  # -> RemoteButtons.apk
   ```
   Each lands in `app/build/outputs/apk/release/app-release.apk`; copy it into `apps/` under the name above.

Release builds are signed with the local debug key, as CleanYourTV does for sideloading. An app signed with a different
key cannot update one already on the TV: uninstall it from the TV first, or keep using one key.
