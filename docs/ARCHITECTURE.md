# How PaneRail works

Every decision lives in `PaneRailKit`, which the app and the test bundle both
link, so the logic is covered by unit tests without a window server or a
permission grant.

| Piece | Role |
| --- | --- |
| `FrontmostAppMonitor` | Watches `NSWorkspace` activation, ignoring PaneRail itself |
| `RailItemProvider` | Contributes a section of rows for an app and acts on a click |
| `WindowRailProvider` | Always present: windows read and raised through `AXUIElement` |
| `VivaldiRailProvider` | A second section of workspaces, when app-specific states are switched on |
| `RailCoordinator` | Assembles the sections, routes clicks back to their providers, decides visibility |
| `RailPanels` | Keeps one floating panel per section |
| `RailVisibility` / `RailGeometry` | The pure show/hide rule and the panel maths |
| `RailPanel` | A borderless, non-activating `NSPanel` floating above everything |

`PaneRailKit` is a static library rather than a framework on purpose: the
hardened runtime enables library validation, which refuses to load an embedded
framework whose ad-hoc signature was produced independently of the app's.

## Sections and panels

Providers contribute rather than compete. The window section is always asked
for; an app-specific provider adds another beside it. Replacing windows outright
would take away window switching at the very moment an app has several windows —
a browser with a private window open next to a normal one.

Each section gets a floating panel of its own rather than sharing one. The rail
of windows is then the same object in every application, whatever else is on
screen, and a panel of an app's own states is a separate thing to place and
size. Positions are stored per panel, keyed by the section it shows, which is
the only identity a panel has.

Row identity is scoped by section. A window's id is an accessibility element
hash and a workspace's is its position in a list, so the two numbering spaces
overlap freely; without scoping, a click could land in the wrong section or two
rows could highlight at once. `RailSection` stamps its own id onto every item it
adopts, so providers go on using their own numbering and collisions are
impossible by construction rather than by care.

The "appear from n windows" threshold applies to the window section alone. One
window beside eight workspaces is a row of noise, but the workspaces are still
worth showing — so that rail opens with workspaces only.

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
falls back to plain window switching rather than showing nothing. Because that
fallback is indistinguishable from the feature being broken, the Advanced tab
reports what the profile read produced — including, by name, the case where a
Vivaldi update has moved the list.
