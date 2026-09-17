# Yaqazah Product Specification

## Platform

Omarchy Desktop Shell (Quickshell / Hyprland on Linux)

## Users

Muslim developers, power users, and everyday computer users who spend extended hours in front of their screens and want a mindful, unobtrusive companion to protect against heedlessness (*ghaflah*) and keep them anchored to their prayers, remembrance, and faith.

## Product Purpose

Yaqazah (*اليقظة* — The Spiritual Awakening) helps break the digital trance of prolonged computer sessions. It provides an immediate next-prayer countdown in the Omarchy bar, an expansive daily timetable in a click-open panel, theme-matched desktop notifications when prayers begin, and an expandable foundation for daily Athkar, fasting alerts, and Islamic reminders.

## Positioning

Yaqazah is an Omarchy-native Islamic companion: it integrates automatic city-level location detection, region-aware calculation defaults, a theme-integrated shell panel, desktop prayer notifications, and mindful reminders directly into the desktop bar without third-party dependencies.

## Operating Context

The plugin runs continuously as an Omarchy bar widget. Users glance at the next prayer in the bar, open the panel to inspect the full day or toggle juristic schools/methods, and receive timely alerts during their work.

## Capabilities and Constraints

- Installable directly through `omarchy plugin add` with no root privileges needed.
- Automatic location uses IP geolocation at city-level precision, with an instant manual city/country search.
- Calculation methods are recommended by country with full override capabilities across 23 global methods.
- Standard Python 3 and native Linux desktop tools; zero pip or third-party Python package dependencies.
- Local disk caching ensures the timetable remains available and functional even offline or during transient network interruptions.

## Brand Commitments

The product name is Yaqazah. Its mark is an authored monochrome SVG whose rendered accent follows the active Omarchy theme. The interface adheres strictly to Omarchy shell typography, spacing, colors, borders, and panel ergonomics.

## Product Principles

- **Mindfulness over Distraction**: Awakening the user from the digital trance without introducing visual noise or bloat.
- **Immediate Utility**: Useful out of the box with automatic location and calculation defaults, fully customizable in one click.
- **Calm Native Aesthetic**: Stay completely cohesive with the active Omarchy system theme.
- **Resilience**: Fail gracefully by caching schedules locally for offline continuity.
