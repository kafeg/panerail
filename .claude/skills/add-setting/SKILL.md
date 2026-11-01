---
name: add-setting
description: Add, rename or remove a PaneRail setting. Use for every change to a preference. A setting touches five places, and the place that is easy to forget fails without a message. Not for a provider (add-provider) or for looking at the result (visual-check).
---
# add-setting
A setting is more than one edit. Do all five steps, in this order.

## Rules
- ⚠️ Never use `defaults.bool(forKey:)`. It gives `false` both for a setting that is absent and for a setting that is off. Read with `defaults.object(forKey:) as? T ?? fallback`.
- ⚠️ Never assign a `@Published` property inside its own `didSet`. The assignment calls `didSet` again until the stack is full. Put the limit in the setter of a computed property and keep the value in private storage. See `width` and `minimumWindows`.
- A computed property has no `$` projection: expose a publisher for it, as `widthPublisher` and `positionPublisher` do. Without a publisher the setting is stored and then ignored until something else causes a refresh.
- Key names take the prefix `rail.`.
- Three places hold the settings window height: `SettingsView`, `SettingsWindowController` and `PreviewRenderer`. They must agree.
- Give each row one line of explanation with `hint(...)`. Change the hint with the value where the meaning changes. See `modeHint` and `positionHint`.

## Procedure
1. **The store** — `Sources/PaneRailKit/Preferences.swift`. Add a key to the `Key` enum, add a `@Published` property, write to `defaults` in its `didSet`, read the default in `init`.
2. **The diagnostics** — `Sources/PaneRail/PreferencesDiagnostics.swift`. Add the value to `dump`, and a value that differs from the default to `writeProbeValues`. This step is the usual omission: the setting then stays outside the round-trip check, and nobody sees that it never persisted.
3. **The interface** — `Sources/PaneRail/UI/GeneralSettingsView.swift` for a normal setting, `AdvancedSettingsView.swift` for one that depends on another application's internals. A new row usually makes the window taller, so update all three heights, then look at the result with visual-check.
4. **The tests** — `Tests/PaneRailKitTests/PreferencesTests.swift`. Test the default, add the value to `testValuesSurviveARestart`, test each limit both on assignment and on a value read back from a damaged domain.
5. **The round trip.** One process writes, a second reads. The unit tests use their own suite, so they cannot catch a key that never reaches the real domain.
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
6. Update the settings table in `README.md`.

## Gotchas
- The test runner hangs and then dies → a `@Published` property assigned inside its own `didSet` → move the limit into a computed property's setter.
- A setting is stored and has no effect until something else refreshes → a computed property with no publisher → expose one. "Reset to right edge" shipped broken for this reason.
- A setting that is off behaves like one that was never set → `defaults.bool(forKey:)` → use `object(forKey:)` with an explicit fallback.
- The round trip shows the setting missing, while the unit tests pass → it was never added to `dump` / `writeProbeValues` → add it in step 2.
- Old keys survive the round trip → `defaults import` merges → delete the domain first.
- Content reaches the bottom edge of the settings window → the three heights disagree → update all three, then look with visual-check. This has happened twice.

## Boundaries
- An application's internal states: add-provider. Looking at the window: visual-check. Installing and the Accessibility grant: permissions.

<!-- style: ste80 -->
