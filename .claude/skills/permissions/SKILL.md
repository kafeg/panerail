---
name: permissions
description: Install PaneRail locally, or repair a lost Accessibility grant. Use when the rail does not appear, when a build needs real windows, or before you ask the user to grant access.
---

# Install, and keep the Accessibility grant

PaneRail cannot read or raise another application's windows without
Accessibility access. macOS loses that grant easily. Each rule below comes from
a failure in this project.

## Install with `make install`

```sh
make install     # builds Release and copies it into /Applications in place
```

Do not delete the bundle first. macOS forgets the TCC entry when the
application disappears. A stable signature does not prevent this. `make install`
copies in place for this reason.

## Sign with the development certificate

macOS ties the grant to the code signature. Ad-hoc signing makes a new
designated requirement for every build. Every build then looks like a different
application.

```sh
make dev-certificate     # once per machine
codesign -d -r- /Applications/PaneRail.app | tail -1
```

The requirement must name the certificate:
`identifier "dev.kafeg.panerail" and certificate leaf = H"..."`.

A requirement that names `cdhash` means the certificate is absent or invalid.
Check with `security find-identity -v -p codesigning`.

## Run a build that needs the grant

```sh
pkill -f "PaneRail.app/Contents/MacOS/PaneRail"; sleep 2
open -n /Applications/PaneRail.app --args --some-flag
```

Do not start the binary directly. TCC gives accessibility to the parent process
when a shell starts it. The application then reports no permission.

`open` ignores `--args` when the application already runs. It activates the
existing instance. Stop the instance first, and use `-n`.

The application discards stdout when `open` starts it. Each diagnostic flag must
write its report to a file.

## A stable signature is not sufficient

The certificate keeps the requirement stable. It does nothing about entries that
TCC already holds. Installs that deleted the bundle leave dead entries. The list
shows no difference between a live entry and a dead one.

Every obvious check passes while the application has no access:

```sh
security find-identity -v -p codesigning     # the identity is present
codesign -d -r- /Applications/PaneRail.app   # the requirement names the certificate
```

Three dead entries collected here before anyone understood the cause. The switch
in System Settings looked on. Turning on a dead entry does nothing.

Do not examine the signature first. Reset the entries, then ask for the grant.

## Repair the grant

```sh
tccutil reset Accessibility dev.kafeg.panerail
open -n /Applications/PaneRail.app          # this registers the application again
```

Ask the user to turn on the new entry. Ask the user to remove other entries with
the minus button. A later grant can land on a dead entry again.
