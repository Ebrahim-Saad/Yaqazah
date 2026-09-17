# Yaqazah (يقظة)

> **Awaken from the digital trance.**

Yaqazah is an Islamic companion and prayer-time plugin for the Omarchy shell. It helps break the digital trance and heedlessness (*ghaflah*) that often comes with prolonged computer sessions by keeping your spiritual duties front and center. It provides next-prayer countdowns directly in your status bar, opens a calm daily timetable panel, sends theme-matched desktop notifications when prayer begins, and serves as a foundation for daily spiritual reminders and Athkar.

## Features

- Automatic city-level location detection from the public IP
- Manual city and country override through Omarchy plugin settings
- Country-based calculation method recommendation with explicit override
- Shafi and Hanafi Asr calculation
- Daily Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha schedule
- Remaining or elapsed time beside every schedule entry
- Hijri date, location source, method, and school in the panel
- Last-known location and prayer-time caching for transient network failures
- Prayer notifications with an SVG icon recolored from the active Omarchy theme
- Keyboard-friendly native Omarchy popup behavior
- No third-party Python packages

## Requirements

- Omarchy with the plugin-capable `omarchy-shell`
- Python 3.9 or newer
- Internet access for initial location and prayer-time lookup
- `notify-send` for prayer notifications

## Install

The repository root is an Omarchy plugin, so it can be installed directly from its Git URL:

```bash
omarchy plugin add https://github.com/Ebrahim-Saad/yaqazah.git --enable
```

The widget is added to the center section by default. Move it if needed:

```bash
omarchy bar move esaad.yaqazah --section right
```

Third-party plugins run inside `omarchy-shell`; review the source before enabling one.

## Configure

Open **Setup > Plugins > Yaqazah** to change:

- **Location**: `Auto` or `Manual`
- **Manual city / country**: used only in Manual mode
- **Calculation method**: `Auto` or one of the supported Aladhan methods
- **Asr school**: `Shafi` or `Hanafi`
- **Prayer notifications**: enabled or disabled

`Auto` location sends the machine's public IP to an IP geolocation provider and stores only city-level location data. It does not request GPS or precise device location.

## Remove

Remove the plugin and its cached location, prayer schedule, and generated icon with:

```bash
omarchy plugin remove esaad.yaqazah
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
cache_home=${XDG_CACHE_HOME:-"$HOME/.cache"}
rm -rf -- "$state_home/yaqazah" "$cache_home/yaqazah"
```

This resolves the same XDG state and cache directories used by Yaqazah. Removing the plugin does not alter other Omarchy or Hyprland configuration.

## Use

- Left click: open or close the daily prayer panel
- Middle click: refresh location and prayer data
- In the popup:
  - Click the **Location** rail to toggle `Auto (IP)` or search for a city with live suggestions.
  - Click **Method** to open the calculation method picker and select from 23 supported methods.
  - Click **Shafi** or **Hanafi** to toggle the Asr juristic school in 1 click.
  - Changes are saved immediately to Omarchy's settings and update the timetable in real time.
- `R` while the panel is open: refresh
- `Esc`: close active picker or close the panel

The plugin refreshes every 30 seconds. Location is refreshed every six hours; prayer schedules are cached per date, location, method, and Asr school.

## Data Services

- [Aladhan](https://aladhan.com/prayer-times-api) for prayer calculations and Hijri dates
- [ipwho.is](https://ipwho.is/) with [ipapi.co](https://ipapi.co/) fallback for automatic city detection
- [Open-Meteo Geocoding](https://open-meteo.com/en/docs/geocoding-api) for manual city lookup

These HTTPS services are external runtime dependencies. Yaqazah sends coordinates to Aladhan for prayer calculation, sends the public IP to the automatic location providers, and sends a manual city query to Open-Meteo only when Manual location is selected.

## Development

Validate the plugin and run its unit tests:

```bash
omarchy plugin validate .
python3 -m unittest discover -s tests -v
```

For local shell testing, place the checkout at `~/.config/omarchy/plugins/esaad.yaqazah`, enable it, and rescan plugins:

```bash
omarchy plugin enable esaad.yaqazah
omarchy-shell shell rescanPlugins
```

## License

MIT
