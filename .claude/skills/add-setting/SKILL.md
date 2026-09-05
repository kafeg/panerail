---
name: add-setting
description: Add, rename or remove a PaneRail user setting. Use whenever a preference is introduced or changed - a setting touches five places and the ones that are easy to forget are the ones that fail silently.
---

# Adding a setting

A setting is never one edit. Work through all five, in this order.

## 1. The store

`Sources/PaneRailKit/Preferences.swift`

- A key in the `Key` enum, namespaced `rail.<name>`.
- A `@Published` property whose `didSet` writes to `defaults`.
- A default read in `init`, via `defaults.object(forKey:) as? T ?? fallback`.
  Never `defaults.bool(forKey:)` — it cannot tell "off" from "absent".

**Never assign the property inside its own `didSet`.** For a `@Published`
property that recurses until the stack runs out; it took down the whole test
runner once. Clamp in a computed property backed by private storage instead —
see `width` and `minimumWindows`.

A computed property has no `$` projection. If something outside the class needs
to observe it, expose a publisher explicitly, the way `widthPublisher` and
`positionPublisher` do. A setting that publishes nothing will be stored and
then ignored until something unrelated happens to trigger a refresh — that is
exactly how "Reset to right edge" shipped broken.

## 2. The diagnostics

`Sources/PaneRail/PreferencesDiagnostics.swift`

Add the value to `dump`, and a deliberately non-default value to
`writeProbeValues`. Forgetting this is the common miss: the setting then sits
outside the round-trip check and nobody notices it never persisted.

## 3. The interface

`Sources/PaneRail/UI/GeneralSettingsView.swift` for ordinary settings,
`AdvancedSettingsView.swift` for anything that depends on another application's
internals.

Every row carries a one-line `hint(...)`. Where the meaning changes with the
value, the hint changes too — see `modeHint` and `positionHint`.

Adding a row usually means the window has to grow. The height appears in three
places that must agree: `SettingsView`, `SettingsWindowController` and
`PreviewRenderer`. Then check it with the `visual-check` skill; content has
silently reached the bottom edge twice.

## 4. The tests

`Tests/PaneRailKitTests/PreferencesTests.swift`

- The default, in `testDefaults` or `testPositionDefaults`.
- The value in `testValuesSurviveARestart`.
- Anything clamped or coerced, both on assignment and when read back from a
  corrupted domain.

## 5. The round trip, for real

```sh
make build
defaults export dev.kafeg.panerail /tmp/prefs-backup.plist   # keep the user's settings
defaults delete dev.kafeg.panerail
build/Build/Products/Debug/PaneRail.app/Contents/MacOS/PaneRail --preferences-dump
build/Build/Products/Debug/PaneRail.app/Contents/MacOS/PaneRail --preferences-write
build/Build/Products/Debug/PaneRail.app/Contents/MacOS/PaneRail --preferences-dump
defaults delete dev.kafeg.panerail
defaults import dev.kafeg.panerail /tmp/prefs-backup.plist   # and put them back
```

Two separate processes: one writes, another reads. Unit tests use an injected
suite and cannot catch a key that never reaches the real domain.

`defaults import` merges rather than replaces, so delete the domain first or
stale keys survive the restore.

## Finally

Update the settings table in `README.md`.
