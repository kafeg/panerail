---
name: add-provider
description: Add support for another application's internal states, such as tabs, projects or workspaces. Use after probe-app-internals has established what the application allows. Not for a preference (add-setting) or for looking at the result (visual-check).
---
# add-provider
A provider gives the rail one section for one application.

Read `VivaldiRailProvider` before you write a new one. It is the first example.

## Rules
- ⚠️ Investigate the application first with probe-app-internals. Write the provider only after you know what the application allows.
- **Add, do not replace.** The window provider always runs. Your section appears beside the windows: an application with several windows still needs them switchable.
- Give the section a stable id, as a `static let` on the provider. The id is the identity of the panel that shows the section, and positions are stored under it.
- **Number the rows locally.** Use any numbering you want. `RailSection` writes its own id onto each item; read `item.id.value` in `activate` to get your number back.
- Return `nil` from `section` when you have nothing, and `false` from `supports` when you cannot read the application. The rail then shows the windows alone.
- Choose `.glyphs` only when every row has an icon. A row without an icon shows the first letter of its name, and a panel of letters is worse than a list.
- **Cache the source.** The rail asks several times each second. Read a file again only when its modification date changes.
- ⚠️ Report a failure where the user can see it: add a status to the Advanced tab, as `VivaldiWorkspacesStatus` does. A silent return to window switching looks the same as a broken application.
- Put each outside dependency behind a protocol. `VivaldiRailProvider` takes a `ShortcutSending` and a `VivaldiActiveWorkspaceReading`, so the tests use doubles.

## Procedure
1. Conform to `RailItemProvider` in `PaneRailKit`.
```swift
func supports(_ app: FrontmostApp) -> Bool
func section(for app: FrontmostApp) -> RailSection?
func activate(_ item: RailItem, in app: FrontmostApp) -> Bool
```
2. Add the provider to `appSpecificProviders` in `AppDelegate`. `RailPanels` makes the panel; you do not create a window.
3. Give it any setting it needs, with add-setting.
4. Describe it under "Supported applications" in `AdvancedSettingsView`.
5. Add it to the app-specific states section in `README.md`.
6. Write a pure parser for any file format and test it against fixtures. Test every way the format can fail: a future update of that application will change it.
7. Ask the user to confirm the application really switched. Tests cannot check that.

## Gotchas
- The provider stores a position and the panel loses it → the section id changed between builds → keep the id a `static let` and never derive it from a name.
- `activate` gets a number you did not expect → you read your own index instead of the item's → read `item.id.value`.
- The panel shows a column of letters → `.glyphs` was chosen while some rows have no icon → use the list mode.
- The rail stutters → the source file is parsed on every poll → compare the modification date first.
- The rail silently shows windows only → `supports` returned `false` and nothing said why → add a status row to the Advanced tab.

## Boundaries
- Finding out what an application allows: probe-app-internals. A preference the provider needs: add-setting. Looking at the panel: visual-check. The Accessibility grant a live run needs: permissions.

<!-- style: ste80 -->
