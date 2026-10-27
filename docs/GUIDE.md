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
| 6. Apps | Installs the OpenTV home screen, Weather and World Clock; optionally SmartTube (latest stable for the TV's CPU, SHA-256 checked) next to stock YouTube | Voice search plays in stock YouTube |
| 7. Home | Starts the new home and sets it as Home. A plain Android TV launcher is disabled (then checked, and turned back on if Home is not OpenTV); the Google TV home is kept on for voice search | The Home guard from CleanYourTV |
| 8. Theme | Pushes `theme/config.json` (with your name and city) and the festival wallpapers, then restarts Home | |
| 9. Home helper | Turns on the launcher's HomeKeyService (window events only, no key filtering) and checks it is running | See the trade-off below |
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

## Remote buttons, Home and voice search: the trade-off

Tested on the Xiaomi MiTV-AXFR2; other Google TVs are likely the same.

- **The Google TV home (launcherx) stays on.** Only it shows the Assistant's voice search results and receives the
  remote's YouTube button (`BUTTON_3` in `dumpsys window policy`). With it off, voice search says "having trouble" and the
  YouTube button does nothing.
- **It always gets the Home press first.** It is a system app with a higher priority than any downloaded launcher,
  so Android picks it even though OpenTV is the saved default and holds the HOME role. The launcher's HomeKeyService
  (`stock_home_redirect`) sees its screen appear and brings OpenTV back (0.4 to 1.2 s), leaving voice search results
  alone for 30 s after the Assistant.
- **Why not catch the Home key directly?** A helper that filters key events (`key_filter` true, `home_long_press_home`)
  does give an instant Home, but this firmware then drops held-key repeat: Volume moves one step per press. Choose it in
  `theme/config.json` if you prefer instant Home over a ramping Volume.
- **SmartTube** is an extra app; stock YouTube is not turned off.

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
