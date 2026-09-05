---
name: visual-check
description: Look at a PaneRail interface change. Use after touching any view, layout or screenshot - this machine has no Screen Recording permission, so screencapture returns wallpaper without windows and the app must draw itself off-screen instead.
---

# Seeing the interface

`screencapture` here produces the desktop picture with **no windows in it** —
the shell has no Screen Recording permission. Do not use it to check the app and
do not conclude from an empty screenshot that nothing was drawn.

The app renders itself off-screen instead. Always open the resulting PNG and
look at it. A zero exit code means a file was written, not that the layout is
right.

## Commands

```sh
BIN=build/Build/Products/Debug/PaneRail.app/Contents/MacOS/PaneRail
$BIN --render-preview  /tmp/rail.png [--dark]        # the rail, scripted data
$BIN --render-settings /tmp/gen.png  [--dark]        # General tab
$BIN --render-settings /tmp/adv.png  --advanced      # Advanced tab
$BIN --render-strip    /tmp/strip.png [--dark]       # the horizontal layout
```

Rendering against a live application needs the Accessibility grant, so it runs
from the installed copy through `open`:

```sh
pkill -f "PaneRail.app/Contents/MacOS/PaneRail"; sleep 1
open -n /Applications/PaneRail.app --args --render-live com.vivaldi.Vivaldi /tmp/live.png [--strip] [--dark]
sleep 8
```

`make preview` refreshes every scripted shot in `docs/`; `make preview-rail
APP_ID=...` refreshes the live ones.

## Traps that have actually cost time here

**An unknown flag does not fail.** The app just launches and runs forever. A
mistyped render flag hung a command for ten minutes. Check the flag exists in
`DeveloperCommands.swift` before running it.

**`timeout` does not exist on macOS.** A guard written with it fails with
"command not found" and looks exactly like the render failing.

**Off-screen there is no window behind the view.** Dark-mode content lands on
white unless the renderer supplies a backdrop. If a dark render looks broken,
suspect the harness before the view.

**A missing SF Symbol draws nothing at all.** `Image(systemName:)` fails
silently for a name that does not exist — `line.3.vertical` is one. If part of a
view is simply absent, check the symbol name exists before debugging layout.

## What this cannot tell you

Rendering shows what a view looks like, never how it behaves. Clicks, drags,
hovers and tooltips have to be tried by the user. Every interaction bug in this
project — an invisible grip, a grip that drew but did not drag, tooltips that
never appear — passed a visual check and a green test suite.

After a change that touches interaction, install it and ask the user to try the
specific gesture. Do not report interaction as working on the strength of tests.
