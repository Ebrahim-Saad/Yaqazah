# Yaqazah Design

## Direction

Yaqazah is a theme-native operational timetable and Islamic companion. It should feel like a first-party Omarchy panel: precise, compact, calm, and immediately scannable rather than decorative or app-like.

## Visual System

- Use `Color`, `Style`, and the active bar's foreground/font bindings for every surface.
- Use the popup background and border supplied by `KeyboardPanel`; do not add an independent card shell.
- Use the active Omarchy accent only for the next prayer, the current-time emphasis, and the SVG mark.
- Secondary information is a darker derivative of the active foreground, never a fixed gray.
- The Yaqazah SVG is monochrome and rendered into cache with the current theme accent or foreground.

## Composition

- The header joins the Yaqazah mark, next prayer, countdown, and exact time in one horizontal read.
- Location and Hijri date share a quiet information rail directly below the header.
- Prayer rows form one aligned timetable with name, exact time, and relative interval columns.
- The next prayer receives a theme-derived selection fill.
- Interactive calculation method picker and Asr school switchers provide instant customization directly in the popup.
- Location rail allows direct switching between Auto detection and manual city search with real-time suggestions.
- Method, school, and location source remain in a low-emphasis footer.

## Typography And Spacing

- Inherit Omarchy's configured font family and `Style.font` scale.
- Use bold weight for the next prayer and exact times; do not introduce a display typeface.
- Use `Style.space`, `Style.spacing`, and `Style.cornerRadius` so density and geometry adapt with shell settings.

## Interaction

- Left click toggles the panel; middle click refreshes.
- Click location to toggle between Auto IP detection and manual city search with live suggestions.
- Click Method to filter and select from 23 calculation methods.
- Click Shafi / Hanafi to switch Asr calculation school in one click.
- Changes immediately persist to Omarchy shell settings and recalculate prayer times.
- `R` refreshes and `Esc` closes pickers, search fields, or the panel.
- Keep the last good schedule visible during refreshes or transient network failures.
- Errors name the recovery action: connection or location settings.
