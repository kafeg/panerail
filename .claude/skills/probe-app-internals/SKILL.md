---
name: probe-app-internals
description: Investigate another application's internal state for a rail provider. Use before adding support for an app's own states, or when existing support stops working - this touches the user's live applications and has broken one of them before.
---

# Probing another application

Everything a provider knows about another app is undocumented and discovered by
experiment. The experiments run against the user's real, running applications,
so the order below is about doing the least damage first.

## Look on disk before touching the app

Chromium-based apps keep a great deal in a profile JSON. Vivaldi's workspace
list, including each workspace's icon as inline SVG, lives in
`~/Library/Application Support/<App>/Default/Preferences`.

Reading a file changes nothing and can be done freely. Do it first, and print
only structure — key names, types, counts. Titles, names and URLs in there are
the user's data.

## Then the accessibility tree, read-only

Add a probe flag to the app rather than driving the target from a shell: the
probe inherits the Accessibility grant, a shell command does not. See
`VivaldiProbe` and the `permissions` skill for how to launch it.

Report matches **by index, not by value** — "workspace #3" rather than its name.
The probe already reads the list from disk, so matching by name and printing the
position tells you everything without putting the user's data in a log.

## Never open the target's menus programmatically

An open macOS menu grabs all input. A probe that pressed a menu item and left
the menu open made the browser stop responding to clicks entirely, and looked
like a crash. If a menu must be inspected, read its items through the
accessibility tree without opening it.

## Do not trust state that updates lazily

Chromium rebuilds its menus only when they are shown. Reading a menu right after
a switch reports the *previous* state, which twice convinced me a working
mechanism was broken.

When a check disagrees with what should have happened, suspect the check.
The cheapest way to settle it: send one action and ask the user what they saw.
That resolved in one round what two hours of automated verification had got
wrong.

## Expect the obvious approach to fail silently

On Vivaldi, `AXPress` on a workspace menu item returns success and does nothing,
because the item is not wired up until its menu opens. Synthesised modifiers set
as flags on a key event are ignored by Chromium; they have to be sent as real
key-down and key-up events. Neither failure reports an error.

Verify by effect, never by return value.

## Fail soft, and say so

Any provider built on this must fall back to plain window switching when its
assumptions stop holding — and must report why, the way the Advanced tab reports
the profile read. A silent fallback is indistinguishable from a broken app.
