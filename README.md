# Yaqazah (يقظة)

> **Awaken from the digital trance.**

Yaqazah is an Islamic companion and prayer-time plugin for the Omarchy shell. It helps break the digital trance and heedlessness that often comes with long computer sessions. It provides next-prayer countdowns directly in your status bar, opens daily prayer times, sends theme-matched desktop notifications when prayer begins, and serves as a foundation for daily prayer reminders.

## Features

- Automatic & Manual city-level location detection from the public IP
- Country-based calculation method recommendation with explicit override
- Shafi and Hanafi Asr calculation
- Daily Fajr, Sunrise, Dhuhr, Asr, Maghrib, and Isha schedule
- Remaining or elapsed time beside every schedule entry
- Hijri date, location source, method, and school in the panel
- Last-known location and prayer-time caching for transient network failures
- Prayer notifications with an icon recolored from the active Omarchy theme

## Requirements

- Omarchy with the plugin-capable `omarchy-shell`
- Python 3.9 or newer
- Internet access for initial location and prayer-time lookup
- `notify-send` for prayer notifications

## Install

It can be installed directly from its Git URL:

```bash
omarchy plugin add https://github.com/Ebrahim-Saad/yaqazah.git --enable
```

Move it if needed:

```bash
omarchy bar move esaad.yaqazah --section right
```

## Configure

Open the in-popup **Settings** page:

- **Bar widget look**:
  - `Countdown`: Always show remaining time countdown, e.g. `1h 30m`.
  - `Time`: Always show exact scheduled prayer clock time, e.g. `15:30`.
  - `Smart`: Show scheduled prayer time (`15:30`) until less than 1 hour remains, then automatically switch to countdown (`45m`).
- **Bar widget separator**:
  - Choose between presets (`· Dot`, `- Dash`, `| Pipe`, `: Colon`, `( ) Parens`, `Space`) or specify any custom separator.
- **Time system**:
  - `24-hour`: Standard 24-hour clock display, e.g. `15:30`.
  - `12-hour`: 12-hour clock format with AM/PM, e.g. `3:30 PM`.
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
