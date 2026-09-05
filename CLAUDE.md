# PaneRail

A floating rail listing the windows of the frontmost macOS app, one click to
switch. Accessory app, no Dock icon, non-activating panel.

- Architecture: `docs/ARCHITECTURE.md`
- Building and releasing: `docs/BUILDING.md`
- Skills: `add-setting`, `visual-check`, `release`, `permissions`,
  `probe-app-internals`

## Rules

**Nothing from this machine goes into the code or the screenshots.** Demo data
is invented — never window titles, project names, paths or anything else read
from the environment. Real project names once reached a public repository this
way. Anything rendered from live data is shown to the user before it is
committed.

**Tests cover the logic; they say nothing about behaviour.** Clicks, drags and
hovers cannot be verified here — `screencapture` has no Screen Recording
permission and returns wallpaper without windows. After changing anything
interactive, install it and ask the user to try that specific gesture. Every
interaction bug in this project passed a green test suite first.

**One place decides whether the rail appears.** `RailVisibility`, in two halves:
`isEligible` for everything that does not need a row count, `meetsThreshold` for
the count. The coordinator calls both and reimplements neither — it drifted once,
and the tests went on passing against the copy that no longer ran.

**Support for another app's internals fails soft and says why.** Fall back to
window switching, and report the reason where the user can see it.

## Working here

`make build`, `make test`, `make install`, `make version`. The `.xcodeproj` is
generated from `project.yml`; edit the yml, not the project.

Everything that makes a decision belongs in `PaneRailKit`, which the tests link
directly. UI and AppKit plumbing stay in the app target.
