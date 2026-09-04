# How PaneRail works

Every decision lives in `PaneRailKit`, which the app and the test bundle both
link, so the logic is covered by unit tests without a window server or a
permission grant.

| Piece | Role |
| --- | --- |
| `FrontmostAppMonitor` | Watches `NSWorkspace` activation, ignoring PaneRail itself |
| `RailItemProvider` | Supplies the rows for an app, acts on a click, and says how they should be laid out |
| `WindowRailProvider` | The default: windows read and raised through `AXUIElement` |
| `VivaldiRailProvider` | Workspaces, when app-specific states are switched on |
| `RailCoordinator` | Picks the provider, holds the rows, decides visibility |
| `RailVisibility` / `RailGeometry` | The pure show/hide rule and the panel maths |
| `RailPanel` | A borderless, non-activating `NSPanel` floating above everything |

`PaneRailKit` is a static library rather than a framework on purpose: the
hardened runtime enables library validation, which refuses to load an embedded
framework whose ad-hoc signature was produced independently of the app's.

## Reading and raising windows

Windows come from the Accessibility API. `CGWindowList` is deliberately avoided:
since Catalina it only returns window titles to an app holding the Screen
Recording permission, which would be a far heavier thing to ask for.

The panel is non-activating, which is what stops a click on the rail from
changing which application is frontmost. The same property means macOS never
draws tooltips for it — the system only does that for the active application.

## Vivaldi workspaces

Workspaces live inside a single window, so window switching does not reach them.
What is possible here was established by probing a running Vivaldi rather than
assumed:

- **The list** comes from `vivaldi.workspaces.list` in the profile's
  `Preferences`, including each workspace's icon, which Vivaldi stores as inline
  SVG rather than a reference into an icon set. There is no API for any of this:
  the `vivaldi.*` JavaScript namespace is reachable only from Vivaldi's own
  bundled UI, and its AppleScript dictionary is the stock Chromium one. The file
  is re-read only when it changes.
- **Switching** sends Vivaldi's built-in `Ctrl+Shift+<n>` shortcut. Pressing the
  matching menu item through the Accessibility API reports success and does
  nothing, because Chromium wires those items up only while the menu is open.
  The modifiers must be sent as real key events too: Chromium ignores modifiers
  that are merely set as flags on the key event. `Ctrl+Shift+1` selects the
  window's own tabs rather than a workspace, so the first workspace answers to
  the second digit — and only eight are reachable.
- **The active workspace** is read from the "Other Workspaces and Tabs" menu,
  which lists every workspace except the one in use. Only the menu bar is
  walked and the submenu is cached, since Vivaldi carries a couple of thousand
  menu items. The submenu is identified by its contents rather than its title,
  so a localised Vivaldi still works.
- **Icons** are drawn by a deliberately restricted SVG reader: Vivaldi's glyphs
  use only paths and lines with absolute commands, so a small parser and Core
  Graphics do what a web view would otherwise do asynchronously and at much
  greater cost. Anything the parser does not understand makes it drop the icon
  rather than draw a distorted shape.

All of it is undocumented internal structure, so every failure is soft: the app
falls back to plain window switching rather than showing nothing.
