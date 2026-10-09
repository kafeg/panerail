---
name: probe-app-internals
description: Investigate another application's internal state. Use before you support an app's own states, or when existing support stops working. This touches the user's live applications and has broken one of them.
---

# Investigate another application

A provider knows nothing about another application until you find it out by
experiment. The experiments run against the user's real applications. Do the
least damaging step first.

## 1. Read the disk first

Chromium applications keep much of their state in a profile JSON file. Vivaldi
keeps the workspace list, with each icon as inline SVG, in
`~/Library/Application Support/<App>/Default/Preferences`.

A file read changes nothing. Do it first.

Print the structure only: key names, types and counts. The titles, names and
URLs in that file are the user's data.

## 2. Then read the accessibility tree

Put the probe in the application. Do not drive the target from a shell. The
probe gets the Accessibility grant. A shell command does not. See the
`permissions` skill for how to start it.

Report each match by index, not by value. Write "workspace #3", not its name.
The probe already has the list from the disk, so an index identifies the match
and keeps the user's data out of the log.

## 3. Never open the target's menus

An open macOS menu takes all input. A probe pressed a menu item, left the menu
open, and the browser stopped answering clicks. It looked like a crash.

Read menu items through the accessibility tree. Do not open the menu.

## Do not trust state that updates late

Chromium builds its menus again only when it shows them. A menu read just after
a switch reports the previous state. This made a working mechanism look broken,
twice.

Suspect your check when the check disagrees with the expected result.

The cheapest way to settle the question: send one action, then ask the user what
they saw. This answered in one exchange what two hours of automated checks got
wrong.

## Expect silent failure

`AXPress` on a Vivaldi workspace menu item returns success and does nothing. The
item has no action until its menu opens.

Chromium ignores a modifier that is only a flag on a key event. Send the
modifier as a real key-down and key-up event.

Neither failure reports an error. Verify by effect, never by return value.

## Report the outcome

A provider built on this must return to plain window switching when its
assumptions fail. It must also report the reason, as the Advanced tab reports
the profile read. A silent fallback looks the same as a broken application.
