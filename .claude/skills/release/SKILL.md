---
name: release
description: Make a PaneRail release. Use when you must tag, publish or ship a version. The version comes from the commit count, and the published archive is checked afterwards. Not for installing locally (permissions) or for looking at the interface (visual-check).
---
# release
Tag a change in behaviour, let CI publish it, then check what was published.

## Rules
- ⚠️ Release only a change in behaviour. Ask one question: does a user see a difference? Do not release a change to documentation, to skills or to the build tooling — keep those for the next release that changes behaviour. A release a user cannot tell apart from the previous one is noise, and it makes the list of releases harder to read when somebody needs to know which version brought which change.
- The main branch always holds the latest work. Anyone who needs it can build from source.
- ⚠️ Read the version after the last commit. Each commit increases the count, so a number from before the commit is already wrong, and a wrong tag gives a release whose contents disagree with its name.
- The version format is `<major>.<minor>.<commits>`. You choose the first two numbers in `project.yml`; `Scripts/stamp-version.sh` writes the commit count into the built `Info.plist`.
- The tag message becomes part of the release notes. Write what changed for a user.
- Keep the sentence about the blocked first launch while builds have no notarisation.

## Procedure
1. Read the version after the last commit.
```sh
make version        # for example 0.1.23 — use this name, with a v in front
```
2. Tag and push.
```sh
git tag -a "v$(make version)" -m "..."
git push origin "v$(make version)"
```
3. Wait for the workflow, then download the archive and look inside it.
```sh
curl -s "https://api.github.com/repos/kafeg/panerail/releases/tags/vX.Y.Z" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['assets'][0]['browser_download_url'])"
# download the file, unzip it, then:
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" PaneRail.app/Contents/Info.plist
```
   The version in the bundle must equal the tag.

## Gotchas
- The bundle's version does not match the tag → the tag was made from a version read before the last commit, or CI used a shallow clone whose commit count differs → re-read `make version` after the commit and check the published build, not the local one. This check also catches a workflow that published the wrong build.
- The release is signed ad-hoc and the notes lack the "Open Anyway" instructions → the repository secrets are absent, so `.github/workflows/release.yml` skipped signing and notarisation → keep the instructions in the notes; nothing is done at release time in either case.

## Boundaries
- Installing locally and the Accessibility grant: permissions. Looking at the interface: visual-check. Building: `docs/BUILDING.md`.

<!-- style: ste80 -->
