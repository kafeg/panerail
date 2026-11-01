---
name: probe-app-internals
description: Investigate another application's internal state. Use before you support an app's own states, or when existing support stops working. This touches the user's live applications and has broken one of them. Not for writing the provider itself (add-provider).
---
# probe-app-internals
A provider knows nothing about another application until you find it out by experiment.

The experiments run against the user's real applications. Do the least damaging step first.

## Rules
- ⚠️ Never open the target's menus. An open macOS menu takes all input: a probe pressed a menu item, left the menu open, and the browser stopped answering clicks. It looked like a crash. Read menu items through the accessibility tree instead.
- ⚠️ Verify by effect, never by return value. Two silent failures live here: `AXPress` on a Vivaldi workspace menu item returns success and does nothing, because the item has no action until its menu opens; and Chromium ignores a modifier that is only a flag on a key event, so send the modifier as a real key-down and key-up.
- ⚠️ The user's data stays out of the log. Print structure only — key names, types and counts. Report each match by index: write "workspace #3", not its name. The probe already has the list from the disk, so an index identifies the match.
- Put the probe inside the application; do not drive the target from a shell. The probe gets the Accessibility grant, a shell command does not. See permissions for how to start it.
- Suspect your check when it disagrees with the expected result. Chromium builds its menus again only when it shows them, so a menu read just after a switch reports the previous state.
- A provider built on this must fall back to plain window switching when its assumptions fail, and report the reason, as the Advanced tab reports the profile read.

## Procedure
1. Read the disk first: a file read changes nothing. Chromium applications keep much of their state in a profile JSON file; Vivaldi keeps the workspace list, each icon as inline SVG, in `~/Library/Application Support/<App>/Default/Preferences`.
2. Read the accessibility tree next, from a probe running inside the application.
3. Send one action, then ask the user what they saw. This is the cheapest way to settle a question: it answered in one exchange what two hours of automated checks got wrong.
4. Report the outcome: what the application allows, what it refuses, and which checks cannot be trusted.

## Gotchas
- A check says the switch did not happen, but it did → a Chromium menu was read right after the switch and reports the previous state → re-read after the menu is shown again, or confirm with the user. This made a working mechanism look broken twice.
- An action returns success and nothing happens → `AXPress` on an item whose menu is closed → verify by effect.
- A modifier has no effect → it was set as a flag on a key event → send real key-down and key-up events.
- The browser stops answering clicks → a menu was left open by a probe → never open menus.
- The log contains the user's window titles or project names → values were printed instead of indexes → print structure and indexes only.

## Boundaries
- Writing the provider: add-provider. Starting a build with the Accessibility grant: permissions. Looking at the resulting panel: visual-check.

<!-- style: ste80 -->
