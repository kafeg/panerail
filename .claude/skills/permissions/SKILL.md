---
name: permissions
description: Install PaneRail locally, or repair a lost Accessibility grant. Use when the rail does not appear, when a build needs real windows, or before you ask the user to grant access. Not for looking at the interface (visual-check) or for probing another app (probe-app-internals).
---
# permissions
PaneRail cannot read or raise another application's windows without Accessibility access, and macOS loses that grant easily.

Every rule below comes from a failure in this project.

## Rules
- ⚠️ Do not delete the bundle before installing. macOS forgets the TCC entry when the application disappears, and a stable signature does not prevent it. `make install` copies in place for this reason.
- ⚠️ Sign with the development certificate. Ad-hoc signing makes a new designated requirement for every build, so every build looks like a different application.
- ⚠️ Do not start the binary directly. TCC gives accessibility to the parent process when a shell starts it, and the application then reports no permission. Use `open`.
- `open` ignores `--args` when the application already runs: it activates the existing instance. Stop the instance first and pass `-n`.
- The application discards stdout when `open` starts it. Every diagnostic flag must write its report to a file.
- ⚠️ A stable signature is not sufficient. The certificate keeps the requirement stable and does nothing about entries TCC already holds. Reset the entries first, then ask for the grant — do not examine the signature first.

## Procedure
1. Install in place.
```sh
make install     # builds Release and copies it into /Applications in place
```
2. Make the signature stable, once per machine, and check it.
```sh
make dev-certificate
codesign -d -r- /Applications/PaneRail.app | tail -1
```
   The requirement must name the certificate: `identifier "dev.kafeg.panerail" and certificate leaf = H"..."`.
3. Run a build that needs the grant.
```sh
pkill -f "PaneRail.app/Contents/MacOS/PaneRail"; sleep 2
open -n /Applications/PaneRail.app --args --some-flag
```
4. The rail still has no access — repair the grant.
```sh
tccutil reset Accessibility dev.kafeg.panerail
open -n /Applications/PaneRail.app          # this registers the application again
```
5. Ask the user to turn on the new entry, and to remove the other entries with the minus button. A later grant can land on a dead entry again.

## Gotchas
- Every obvious check passes and the application still has no access → TCC holds a dead entry from an install that deleted the bundle → the list shows no difference between a live entry and a dead one, and turning on a dead entry does nothing. Reset. Three dead entries collected here before anyone understood the cause.
- The requirement names `cdhash` instead of the certificate → the certificate is absent or invalid → check with `security find-identity -v -p codesigning`, then `make dev-certificate`.
- A flag passed with `open` has no effect → the application was already running → `pkill` it, then `open -n`.
- A diagnostic prints nothing → `open` discards stdout → have the flag write to a file.

## Boundaries
- Looking at a rendered interface: visual-check. Probing another application's state: probe-app-internals. Building and releasing: `docs/BUILDING.md`.

<!-- style: ste80 -->
