---
name: permissions
description: Install PaneRail locally or deal with the Accessibility grant disappearing. Use when the rail stops appearing after a rebuild, when a build needs testing against real windows, or before asking the user to grant access again.
---

# Installing, and keeping the Accessibility grant

The rail cannot read or raise another app's windows without Accessibility
access, and macOS loses that grant more easily than it looks. Every rule below
exists because it was learned the hard way; the user was asked to re-grant five
times in one session before the causes were understood.

## Install with `make install`, never by hand

```sh
make install     # builds Release and rsyncs it into /Applications in place
```

**Do not delete the bundle first.** `rm -rf /Applications/PaneRail.app` followed
by a copy makes macOS forget the TCC entry, however stable the signature is.
`make install` updates in place for exactly this reason.

## Sign with the development certificate

macOS ties the grant to the app's code signature. Ad-hoc signing produces a new
designated requirement on every build — `cdhash H"..."` — so every rebuild looks
like a different app.

```sh
make dev-certificate     # once per machine; creates a stable self-signed identity
codesign -d -r- /Applications/PaneRail.app | tail -1
```

The requirement should read `identifier "dev.kafeg.panerail" and certificate
leaf = H"..."`. If it says `cdhash`, the certificate is missing or invalid and
the grant will keep vanishing — `security find-identity -v -p codesigning`.

## Running a build that needs the grant

```sh
pkill -f "PaneRail.app/Contents/MacOS/PaneRail"; sleep 1
open -n /Applications/PaneRail.app --args --some-flag
```

**Not the binary directly.** Running `.../Contents/MacOS/PaneRail` from a shell
makes TCC attribute accessibility to the parent process, so the app reports no
permission however correctly it was granted.

**`open` ignores `--args` when the app is already running** — it just activates
the existing instance. Kill it first, and use `-n`.

Output goes nowhere when launched this way, so any diagnostic flag must write
its report to a file passed as an argument.

## When the grant is genuinely gone

```sh
tccutil reset Accessibility dev.kafeg.panerail
open -n /Applications/PaneRail.app          # registers the app in the list
```

Reset before asking the user to grant again. Stale entries accumulate — three of
them at once, at one point — and switching on a dead one does nothing, which
looks exactly like the app being broken. Then ask the user to enable the single
fresh entry, or add `/Applications/PaneRail.app` with **+**.
