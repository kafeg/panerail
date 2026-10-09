---
name: add-setting
description: Add, rename or remove a PaneRail setting. Use for every change to a preference. A setting touches five places, and the place that is easy to forget fails without a message.
---

# Add a setting

A setting is more than one edit. Do all five steps, in this order.

## 1. The store

File: `Sources/PaneRailKit/Preferences.swift`

- Add a key to the `Key` enum. Use the prefix `rail.`.
- Add a `@Published` property. Write to `defaults` in its `didSet`.
- Read the default in `init` with `defaults.object(forKey:) as? T ?? fallback`.

Do not use `defaults.bool(forKey:)`. It gives `false` for a setting that is
absent and for a setting that is off.

Do not assign a `@Published` property inside its own `didSet`. The assignment
calls `didSet` again until the stack is full. This stopped the whole test runner
once. Put the limit in the setter of a computed property, and keep the value in
private storage. See `width` and `minimumWindows`.

A computed property has no `$` projection. Expose a publisher for it, as
`widthPublisher` and `positionPublisher` do. Without a publisher the setting is
stored and then ignored until something else causes a refresh. "Reset to right
edge" shipped broken for this reason.

## 2. The diagnostics

File: `Sources/PaneRail/PreferencesDiagnostics.swift`

Add the value to `dump`. Add a value that differs from the default to
`writeProbeValues`.

This step is the usual omission. The setting then stays outside the round-trip
check, and nobody sees that it never persisted.

## 3. The interface

File: `Sources/PaneRail/UI/GeneralSettingsView.swift` for a normal setting.
File: `Sources/PaneRail/UI/AdvancedSettingsView.swift` for a setting that
depends on another application's internals.

Give each row one line of explanation with `hint(...)`. Change the hint with the
value where the meaning changes. See `modeHint` and `positionHint`.

A new row usually makes the window taller. Three places hold the height:
`SettingsView`, `SettingsWindowController` and `PreviewRenderer`. They must
agree. Then look at the result with the `visual-check` skill. Content has
reached the bottom edge twice.

## 4. The tests

File: `Tests/PaneRailKitTests/PreferencesTests.swift`

- Test the default.
- Add the value to `testValuesSurviveARestart`.
- Test each limit, on assignment and on a value read back from a damaged domain.

## 5. The round trip

```sh
make build
BIN=build/Build/Products/Debug/PaneRail.app/Contents/MacOS/PaneRail
defaults export dev.kafeg.panerail /tmp/prefs-backup.plist   # keep the user's settings
defaults delete dev.kafeg.panerail
$BIN --preferences-dump
$BIN --preferences-write
$BIN --preferences-dump
defaults delete dev.kafeg.panerail
defaults import dev.kafeg.panerail /tmp/prefs-backup.plist   # give them back
```

One process writes. A second process reads. The unit tests use their own suite,
so they cannot find a key that never reaches the real domain.

`defaults import` merges. Delete the domain first, or old keys stay.

## 6. Finally

Update the settings table in `README.md`.
