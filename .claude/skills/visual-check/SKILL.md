---
name: visual-check
description: Look at a PaneRail interface change. Use after you change a view, a layout or a screenshot. This machine has no Screen Recording permission, so the app must draw itself off-screen.
---

# Look at the interface

`screencapture` gives you the desktop picture with no windows in it. The shell
has no Screen Recording permission. Do not use it to check the app. An empty
screenshot does not mean the app drew nothing.

The app draws itself off-screen instead. Open the PNG and look at it. A zero
exit code tells you that a file exists. It does not tell you that the layout is
correct.

## Commands

```sh
BIN=build/Build/Products/Debug/PaneRail.app/Contents/MacOS/PaneRail
$BIN --render-preview  /tmp/rail.png   [--dark]    # the rail of windows
$BIN --render-settings /tmp/gen.png    [--dark]    # the General tab
$BIN --render-settings /tmp/adv.png    --advanced  # the Advanced tab
$BIN --render-glyphs   /tmp/glyphs.png [--dark]    # the glyph panel
```

A render against a running application needs the Accessibility grant. Start it
with `open`:

```sh
pkill -f "PaneRail.app/Contents/MacOS/PaneRail"; sleep 2
open -n /Applications/PaneRail.app --args --render-live com.vivaldi.Vivaldi /tmp/live.png [--strip] [--dark]
sleep 10
```

Start one render at a time. Stop the previous instance first. Two instances at
once leave the second one writing nothing.

`make preview` makes the scripted shots again. `make preview-rail APP_ID=...`
makes the live ones again.

## Traps

**An unknown flag does not fail.** The app starts and runs forever. Check the
flag in `DeveloperCommands.swift` before you use it.

**`timeout` does not exist on macOS.** A command that uses it fails with
"command not found". This looks like a failed render.

**`open` does not pass the working directory to the app.** Give an absolute
path. A relative path writes somewhere else. Use `$(CURDIR)` in the Makefile.

**The app discards stdout when `open` starts it.** A diagnostic must write its
result to a file. It must write its failures to a file as well.

**zsh does not split an unquoted variable into words.** bash does. Put the
arguments in the command. Do not build them in a variable. This trap made files
with names like `strip-dark.png --strip --dark`.

**A missing SF Symbol draws nothing.** `Image(systemName:)` fails without a
message for a name that does not exist. `line.3.vertical` is one such name. If
part of a view is absent, check the symbol name first.

## Limit

A render shows you the view. It tells you nothing about behaviour. Only the user
can test a click, a drag or a hover.

Install the build. Ask the user to try the gesture you changed. Every
interaction fault in this project passed a render and a green test suite.
