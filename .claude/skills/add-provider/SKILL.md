---
name: add-provider
description: Add support for another application's internal states, such as tabs, projects or workspaces. Use after the probe-app-internals skill has established what the application allows.
---

# Add a provider

A provider gives the rail one section for one application. Vivaldi workspaces
are the first example. Read `VivaldiRailProvider` before you write a new one.

Investigate the application first with the `probe-app-internals` skill. Write
the provider only after you know what the application allows.

## The contract

Conform to `RailItemProvider` in `PaneRailKit`:

```swift
func supports(_ app: FrontmostApp) -> Bool
func section(for app: FrontmostApp) -> RailSection?
func activate(_ item: RailItem, in app: FrontmostApp) -> Bool
```

Give the section a stable id, as a `static let` on the provider. The id is the
identity of the panel that shows the section. Positions are stored under it.

## Rules

**Add, do not replace.** The window provider always runs. Your section appears
beside the windows. An application with several windows still needs them
switchable.

**Number the rows locally.** Use any numbering you want. `RailSection` writes
its own id onto each item. Read `item.id.value` in `activate` to get your
number back.

**Return `nil` when you have nothing.** Return `false` from `supports` when you
cannot read the application. The rail then shows the windows alone.

**Choose `.glyphs` only when every row has an icon.** A row without an icon
shows the first letter of its name. A panel of letters is worse than a list.

**Cache the source.** The rail asks several times each second. Read a file again
only when its modification date changes.

**Report a failure where the user can see it.** Add a status to the Advanced
tab, as `VivaldiWorkspacesStatus` does. A silent return to window switching
looks the same as a broken application.

## Wire it up

1. Add the provider to `appSpecificProviders` in `AppDelegate`.
2. Give it any setting it needs. Use the `add-setting` skill.
3. Describe it under "Supported applications" in `AdvancedSettingsView`.
4. Add it to the app-specific states section in `README.md`.

`RailPanels` makes the panel. You do not create a window.

## Test it

Put each outside dependency behind a protocol. `VivaldiRailProvider` takes a
`ShortcutSending` and a `VivaldiActiveWorkspaceReading`, so the tests use
doubles.

Write a pure parser for any file format, and test it against fixtures. Test
every way the format can fail. A future update of that application will change
it.

Tests cannot check that the application really switched. Ask the user.
