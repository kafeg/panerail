<div align="center">
  <img src="docs/icon.png" width="128" alt="PaneRail icon">
  <h1>PaneRail</h1>
  <p><strong>A minimal floating rail listing every window of the active app on macOS — one click to switch.</strong></p>
</div>

<div align="center">
  <img src="docs/rail-light.png" width="300" alt="PaneRail in light appearance">
  <img src="docs/rail-dark.png" width="300" alt="PaneRail in dark appearance">
</div>

---

macOS has no good way to move between windows of the same app. The Window menu
is three clicks deep, `Cmd+\`` cycles blindly, and Mission Control throws every
other app at you as well.

PaneRail puts a small always-on-top rail on screen listing the windows of
whichever app is in front. Click a row and that window comes forward. Switch to
another app and the rail follows. When there is nothing to switch between, it
gets out of the way.

## Features

- **Follows the front app.** The rail always describes the app you are looking at.
- **Never steals focus.** Clicking the rail does not change which app is active.
- **Stays out of the way.** Hidden until an app has more than one window; the
  threshold is configurable, as is an allow list of specific apps.
- **Drag it anywhere** by its header. The position is remembered.
- **Minimised windows included**, shown dimmed, and restored when clicked.
- **No Dock icon.** It lives in the menu bar, where the icon turns into a
  warning sign if Accessibility access is missing.

## Install

### From source (no Gatekeeper prompts)

Locally built apps are never quarantined, so this is the smoothest route:

```sh
git clone https://github.com/kafeg/panerail.git
cd panerail
make dev-certificate   # once: keeps the Accessibility grant across rebuilds
make install
```

### From Releases

Download the latest `PaneRail.zip` from
[Releases](https://github.com/kafeg/panerail/releases), unzip it and move
`PaneRail.app` to `/Applications`.

Releases are not notarised, so macOS blocks the first launch. On macOS 15 and
later the old Control-click shortcut no longer works: open **System Settings ›
Privacy & Security**, scroll to the message naming PaneRail, click **Open
Anyway** and confirm with your password. This is needed once per version.

### Accessibility permission

PaneRail needs Accessibility access in **System Settings › Privacy & Security ›
Accessibility**. It is the only API macOS offers for reading and raising another
app's windows, so without it the rail has nothing to show. The app asks on first
launch and starts working the moment the switch is flipped — no restart needed.

It reads window titles only. It never records the screen, and deliberately
avoids `CGWindowList`, which would have required the Screen Recording permission
just to see titles.

## Settings

Open them from the gear in the rail's header or from the menu bar icon. The
permission state is the first thing the window reports, and it updates live.

<div align="center">
  <img src="docs/settings-light.png" width="440" alt="PaneRail settings">
</div>

| Setting | What it does |
| --- | --- |
| Show for | All applications, or only the ones ticked in the Apps tab |
| Appear from *n* windows | The rail stays hidden below this many windows. Set it to 1 to always show it |
| Width | 160–380 pt |
| Position | Reset the rail back to the right edge |
| Launch at login | Registers a login item via `SMAppService` |

## App-specific states (experimental)

Some applications keep their own internal states that matter more than their
windows. With **Use an app's own states** switched on — it lives in the Advanced
tab — the rail shows those instead.

It is off by default because it depends on undocumented internals of the app in
question, which that app's next update may change. Whenever those internals
cannot be read, the app falls back to plain window switching.

**Vivaldi** is the one supported so far. Its workspaces all live inside a single
window, so window switching does not help with them at all, and its own picker
is a dropdown at the top of the window. The rail lists the workspaces, marks the
active one and switches with a click.

Two limits worth knowing: only the first eight workspaces can be switched to,
because that is as far as Vivaldi's own keyboard shortcuts reach, and later ones
are listed but dimmed. And a Vivaldi update may break this at any time.

## Building from source

Requires Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). The `.xcodeproj` is generated from `project.yml` and
is not checked in.

```sh
make build            # build the Debug app
make test             # run the unit tests
make demo             # launch against scripted windows, no permission needed
make install          # build Release and update /Applications in place
make package          # build Release and zip it into dist/
```

`make demo` is the fastest way to work on the UI: it swaps the Accessibility
window source for fixed sample data, so nothing needs to be granted.

### Keeping the Accessibility grant across rebuilds

macOS ties the grant to the app's code signature, and ad-hoc signing produces a
new identity on every build — so the permission is lost each time. Run
`make dev-certificate` once to create a local self-signed certificate; `make`
then signs with it and the grant survives. Note that `make install` updates the
bundle in place for the same reason: deleting the app first makes macOS forget
the entry however stable the signature is.

If the rail stops appearing after a rebuild anyway, `make reset-permission`
clears the stale entries so access can be granted cleanly.

## How it works

Every decision lives in `PaneRailKit`, which the app and the test bundle both
link, so the logic is covered by unit tests without a window server or a
permission grant.

| Piece | Role |
| --- | --- |
| `FrontmostAppMonitor` | Watches `NSWorkspace` activation, ignoring PaneRail itself |
| `RailItemProvider` | Supplies the rows for an app and acts on a click |
| `WindowRailProvider` | The default: windows read and raised through `AXUIElement` |
| `VivaldiRailProvider` | Workspaces, when app-specific states are switched on |
| `RailCoordinator` | Picks the provider, holds the rows, decides visibility |
| `RailVisibility` / `RailGeometry` | The pure show/hide rule and the panel maths |
| `RailPanel` | A borderless, non-activating `NSPanel` floating above everything |

`PaneRailKit` is a static library rather than a framework on purpose: the
hardened runtime enables library validation, which refuses to load an embedded
framework whose ad-hoc signature was produced independently of the app's.

## Releasing

Pushing a `v*` tag builds, tests, packages and publishes to Releases.

The workflow signs and notarises when these repository secrets are present,
and falls back to an ad-hoc build when they are not, so it works either way:

| Secret | What it is |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Developer ID Application certificate and key, base64 of a `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | The password that `.p12` was exported with |
| `APPLE_TEAM_ID` | Ten-character team identifier |
| `NOTARY_API_KEY` | App Store Connect API key, base64 of the `.p8` |
| `NOTARY_API_KEY_ID` / `NOTARY_API_ISSUER_ID` | That key's id and issuer |

All of them require a paid Apple Developer Program membership. Note that a
lapsed membership does not break releases already signed and notarised — they
keep installing and running; membership is needed to sign and notarise new ones.

## Limitations

- **Full-screen spaces.** A floating panel over another app's full-screen window
  is unreliable on macOS, regardless of collection behaviour.
- **Raising a window on another Space** switches you to that Space. That is how
  macOS works, not a bug.
- **Not on the Mac App Store, and cannot be.** The App Sandbox blocks
  cross-process Accessibility calls and no entitlement lifts that, which is why
  window managers either predate the sandbox requirement or ship outside the
  Store.

## License

[MIT](LICENSE).
