# OpenTV OS guide

What setup does, in order, and every problem we met on the first TV (Xiaomi MiTV-AXFR2, Google TV on
Android 11, 1.5 GB RAM, 4 GB storage), with its fix. Read this when something on your TV behaves differently.

## What `Setup-My-TV.bat` does

| Step | What happens | Why |
|---|---|---|
| 1. Questions | Your name, your city (looked up on Open-Meteo, you pick the right match), the TV's IP | Name and city go into the theme; nothing is sent anywhere else |
| 2. Connect | Downloads Google's `adb` into `tools\`, connects over Wi-Fi; you accept the prompt on the TV | |
| 3. Backup | App lists, settings, `getprop`, Home and accessibility state into `backup\<model>_<date>\` | Restore uses it |
| 4. Storage | Under 400 MB free → `pm trim-caches 2G` (caches only) | The first TV was 99% full and the install failed |
| 5. Clean-up | Asks per group and per app (`lists/debloat.json`), then `pm disable-user` one package at a time, each written to `disabled-by-setup.txt` | Disable, never uninstall |
| 5b. Setup wizard | On Google TV, disables `setupwraith` **unless** it owns the saved Wi-Fi network (`dumpsys wifi`, `cname=`) | With the stock home off it can crash-loop Home; if it owns Wi-Fi, disabling it drops Wi-Fi |
| 6. Apps | Installs the OpenTV home screen, Weather, World Clock, Remote Buttons; optionally SmartTube (latest stable for the TV's CPU, SHA-256 checked) and turns stock YouTube off | YouTube links then open in SmartTube |
| 7. Home | Starts the new home, disables the stock one, sets the new one as Home, then checks; if Home is not OpenTV it turns the stock home back on | The Home guard from CleanYourTV |
| 8. Theme | Pushes `theme/config.json` (with your name and city) and the festival wallpapers, then restarts Home | |
| 9. Remote | Turns on the launcher's key helper (YouTube button → SmartTube, from Home only) and Remote Buttons (app redirects, never sees keys) | See "Remote buttons" below |
| 10. Finish | Screenshot into the backup folder, offers to turn debugging off | |

## Settings you can change (`theme/config.json`)

Edit it, then run setup again (it is safe to repeat). The keys come from
[CleanYourTV's theme keys](https://github.com/Gathin23/cleanyourtv/blob/main/themes/README.md) plus these:

| Key | What it does |
|---|---|
| `festival: "auto"` | The built-in Indian calendar (dates up to the end of 2027, national days every year) |
| `festival_calendar` | Your own or corrected dates: `"2028-03-11..2028-03-11=holi"`, or `"..=name=Greeting=#RRGGBB"` |
| `festival_icons` | `true`: diya, bell and marigold icons during festival windows |
| `weather_mood`, `weather_pill`, `weather_place`, `weather_latitude`, `weather_longitude` | Sky tint, top-bar pill and the place (setup fills the place in) |
| `add_tile` | The **+ Add app** tile at the end of the grid |
| `key_filter_home_only` | The key helper filters keys only while Home is on screen (see below) |
| `app_keys` | Remote buttons that open an app, e.g. `"KEYCODE_BUTTON_3:org.smarttube.stable"` |
| `dock_apps`, `hidden_apps`, `app_labels`, `columns` | Dock, hidden apps, tile names, columns |

Festival wallpapers are `theme/wallpapers/festival-<name>.jpg`; redraw them with `python theme/make_festival_wallpapers.py`
(needs Python with Pillow) or drop in your own 1920×1080 JPEG with the same name.

## Remote buttons, and why they work the way they do

- **Held Volume moving one step per press** is caused by any accessibility service that *filters key events*
  (CleanYourTV's key helpers, Key Mapper's normal mode). So the helper here filters keys **only while the OpenTV Home is
  on screen** (`key_filter_home_only`): inside every app, keys are untouched and Volume ramps.
- **Which app owns each app button** is set by the TV: `adb shell dumpsys window policy | findstr BUTTON`. On the
  tested Xiaomi, Netflix (`BUTTON_6`) and Prime (`BUTTON_7`) belong to Xiaomi's handler and work as they are, while
  YouTube (`BUTTON_3`) belongs to the Google TV home. With that turned off only the key helper can catch the YouTube
  button, so it opens SmartTube from Home only.
- Turning the Google TV home back on brings the button back everywhere, but on that firmware it then reclaims Home and
  flashes on every Home press (`set-home-activity` and the HOME role do not stick). We kept the instant Home.
- **Remote Buttons** (the app on Home) changes what an app button opens by redirecting the app it opens: "when Prime
  Video opens, open JioHotstar". It only hears which app is in front (`capabilities=0`), never keys.

## Problems we hit, and the fixes

| Problem | Fix |
|---|---|
| `pm install`: "Requested internal only, but not enough space" | `pm trim-caches 2G`, then retry (setup does it) |
| Home crash-loop risk on Google TV | Disable `com.google.android.tungsten.setupwraith` before the stock home goes (setup does it, after the Wi-Fi check) |
| Pushing a big APK through a pure-Python ADB client timed out | Real `adb install` streams it in seconds (setup uses Google's adb) |
| App tiles named "Weather · Forecast and a…" | `app_labels` in the theme beats a module card's caption |
| Voice search for a video says "having trouble" with the Google TV home off | A known Google TV limit: search inside SmartTube |
| One call failed with "unreachable host" | Wi-Fi blip: run it again; `ping <tv ip>` |
| The TV got a new IP after a reboot | Read it again in Settings → Network (or reserve it in your router) |
| The Weather model returned 6 days | The Weather app falls back to Open-Meteo's 16-day model |
| An "Allow USB debugging?" prompt for another device was accepted by an OK press during a test | Always revoke authorisations when you finish (Developer options), and turn debugging off |

## Restore

`Restore-My-TV.bat` picks a backup folder, turns every package in its `disabled-by-setup.txt` back on, gives Home back to
the TV's launcher and turns the OpenTV key helpers off. The OpenTV apps stay installed (unused) until you remove them in
Settings → Apps.
