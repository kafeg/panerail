---
name: release
description: Cut a PaneRail release. Use when asked to tag, publish or ship a version - the version number is computed, not chosen, and the published artifact must be checked rather than assumed.
---

# Releasing

## The version is computed

`<major>.<minor>.<commits>`. Only the first two are chosen by hand, in
`project.yml`; the last is `git rev-list --count HEAD`, stamped into the built
`Info.plist` by `Scripts/stamp-version.sh`.

So the tag name follows the build, not the other way round:

```sh
make version        # e.g. 0.1.23 — tag exactly this, prefixed with v
```

**Read it after the last commit, not before.** Committing bumps the count, so a
number noted earlier is already stale. Tagging the stale one produces a release
whose contents disagree with its name; the workflow warns, but the release is
already published by then.

## Cutting it

```sh
git tag -a "v$(make version)" -m "..."   # what changed, plus the Gatekeeper note
git push origin "v$(make version)"
```

The tag message becomes part of the release notes. Say what changed for a user,
and keep the line about the first launch being blocked while builds are not
notarised.

## Verifying — do not skip this

Wait for the workflow, then **download the published archive and look inside**:

```sh
curl -s "https://api.github.com/repos/kafeg/panerail/releases/tags/vX.Y.Z" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['assets'][0]['browser_download_url'])"
# download, unzip, then:
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" PaneRail.app/Contents/Info.plist
```

The version inside the bundle must equal the tag. This one check catches a
stale tag, a shallow clone miscounting commits, and a workflow that published
the wrong build — all three have been possible here at some point.

## Signing

Signing and notarisation are already written into `.github/workflows/release.yml`
and switch on by themselves once the repository secrets exist; without them the
build is ad-hoc and the release notes gain the "Open Anyway" instructions
automatically. Nothing to do at release time either way.
