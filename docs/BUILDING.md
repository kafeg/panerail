# Building and releasing

Requires Xcode 16 or newer and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). The `.xcodeproj` is generated from `project.yml` and
is not checked in.

```sh
make build            # build the Debug app
make test             # run the unit tests
make demo             # launch against scripted windows, no permission needed
make install          # build Release and update /Applications in place
make package          # build Release and zip it into dist/
make version          # print the version the next build will carry
```

`make demo` is the fastest way to work on the interface: it swaps the
Accessibility window source for fixed sample data, so nothing needs granting.

## Keeping the Accessibility grant across rebuilds

macOS ties the grant to the app's code signature, and ad-hoc signing produces a
new identity on every build, so the permission is lost each time. Run
`make dev-certificate` once to create a local self-signed certificate; `make`
then signs with it and the grant survives.

`make install` updates the bundle in place for a related reason: deleting the
app first makes macOS forget the entry however stable the signature is.

If the rail stops appearing after a rebuild anyway, `make reset-permission`
clears the stale entries so access can be granted cleanly.

## Screenshots

The interface draws itself off-screen, so the images in `docs/` can be
regenerated without a Screen Recording grant:

```sh
make preview                              # settings tabs and the icon strip
make preview-rail APP_ID=com.microsoft.VSCode   # the rail against a running app
```

The rail shots are taken against a real application so the README shows its own
icon; the rest render from scripted data and are reproducible from source alone.

## Versions

Versions are `<major>.<minor>.<commits>`. The last component is the commit
count, stamped into the app at build time by `Scripts/stamp-version.sh`, so any
build says which commit it came from. Only the first two are chosen by hand, in
`project.yml`. `make version` prints what the next build will call itself, which
is the name to give the tag.

## Releasing

Pushing a `v*` tag builds, tests, packages and publishes to Releases.

The workflow signs and notarises when these repository secrets are present, and
falls back to an ad-hoc build when they are not, so it works either way:

| Secret | What it is |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | Developer ID Application certificate and key, base64 of a `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | The password that `.p12` was exported with |
| `APPLE_TEAM_ID` | Ten-character team identifier |
| `NOTARY_API_KEY` | App Store Connect API key, base64 of the `.p8` |
| `NOTARY_API_KEY_ID` / `NOTARY_API_ISSUER_ID` | That key's id and issuer |

All of them require a paid Apple Developer Program membership. A lapsed
membership does not break releases already signed and notarised — they keep
installing and running; membership is needed to sign and notarise new ones.
