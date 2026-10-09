---
name: release
description: Make a PaneRail release. Use when you must tag, publish or ship a version. The version comes from the commit count. Check the published archive.
---

# Make a release

## The version is calculated

The format is `<major>.<minor>.<commits>`. You choose the first two numbers in
`project.yml`. `Scripts/stamp-version.sh` writes the commit count into the
built `Info.plist`.

The tag name follows the build:

```sh
make version        # for example 0.1.23 — use this name, with a v in front
```

Read the version after the last commit. Each commit increases the count. A
number from before the commit is already wrong. A wrong tag gives a release
whose contents disagree with its name.

## Make the tag

```sh
git tag -a "v$(make version)" -m "..."
git push origin "v$(make version)"
```

The message becomes part of the release notes. Write what changed for a user.
Keep the sentence about the blocked first launch while builds have no
notarisation.

## Check the result

Wait for the workflow. Then download the archive and look inside it:

```sh
curl -s "https://api.github.com/repos/kafeg/panerail/releases/tags/vX.Y.Z" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['assets'][0]['browser_download_url'])"
# download the file, unzip it, then:
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" PaneRail.app/Contents/Info.plist
```

The version in the bundle must equal the tag. This check finds a stale tag, a
shallow clone with a wrong commit count, and a workflow that published the wrong
build.

## Signing

`.github/workflows/release.yml` contains the signing and notarisation steps.
They start when the repository secrets exist. Without the secrets the build is
ad-hoc, and the release notes get the "Open Anyway" instructions. You do nothing
at release time in either case.
