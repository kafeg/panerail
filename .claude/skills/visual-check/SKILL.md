---
name: visual-check
description: Look at a PaneRail interface change. Use after you change a view, a layout or a screenshot. This machine has no Screen Recording permission, so the app must draw itself off-screen. Not for behaviour — a click, a drag or a hover can only be tested by the user.
---
# visual-check
The app draws itself off-screen. Open the PNG and look at it.

## Rules
- ⚠️ Do not use `screencapture` to check the app. The shell has no Screen Recording permission, so it returns the desktop picture with no windows in it. An empty screenshot does not mean the app drew nothing.
- A zero exit code tells you that a file exists. It does not tell you the layout is correct. Look at the image.
- Start one render at a time, and stop the previous instance first. Two instances at once leave the second one writing nothing.
- ⚠️ A render shows you the view and tells you nothing about behaviour. Install the build and ask the user to try the gesture you changed. Every interaction fault in this project passed a render and a green test suite.
- Nothing from this machine goes into a committed screenshot. Demo data is invented; anything rendered from live data is shown to the user before it is committed.

## Procedure
1. Render the scripted shots.
```sh
BIN=build/Build/Products/Debug/PaneRail.app/Contents/MacOS/PaneRail
$BIN --render-preview  /tmp/rail.png   [--dark]    # the rail of windows
$BIN --render-settings /tmp/gen.png    [--dark]    # the General tab
$BIN --render-settings /tmp/adv.png    --advanced  # the Advanced tab
$BIN --render-glyphs   /tmp/glyphs.png [--dark]    # the glyph panel
```
2. A render against a running application needs the Accessibility grant, so start it with `open` (see permissions).
```sh
pkill -f "PaneRail.app/Contents/MacOS/PaneRail"; sleep 2
open -n /Applications/PaneRail.app --args --render-live com.vivaldi.Vivaldi /tmp/live.png [--strip] [--dark]
sleep 10
```
3. Open every PNG and look at it: clipped text, content at the bottom edge, missing parts.
4. Remake the committed shots when they changed: `make preview` for the scripted ones, `make preview-rail APP_ID=...` for the live ones.
5. Install the build and ask the user to try the gesture you changed.

## Gotchas
- The app starts and runs forever, no file appears → an unknown flag does not fail → check the flag in `DeveloperCommands.swift` first.
- A command fails with "command not found" and looks like a failed render → `timeout` does not exist on macOS → drop it.
- The PNG is written somewhere else → `open` does not pass the working directory to the app → give an absolute path, `$(CURDIR)` in the Makefile.
- A diagnostic reports nothing, including its failures → the app discards stdout when `open` starts it → write both to a file.
- Files appear with names like `strip-dark.png --strip --dark` → zsh does not split an unquoted variable into words, unlike bash → put the arguments in the command, not in a variable.
- Part of a view is simply absent → `Image(systemName:)` fails without a message for a name that does not exist, as with `line.3.vertical` → check the symbol name first.

## Boundaries
- Installing and the Accessibility grant: permissions. A preference's own round trip: add-setting. Another application's state: probe-app-internals.

<!-- style: ste80 -->
