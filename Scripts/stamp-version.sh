#!/usr/bin/env bash
# Stamps the built app with a version whose last component is the commit count,
# so any build says exactly which commit it came from.
#
# Runs as a build phase, before code signing, and edits the Info.plist inside
# the product rather than the one in the source tree.
set -euo pipefail

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
[ -f "$PLIST" ] || exit 0

cd "${PROJECT_DIR}"

# A tarball or a shallow clone has no history to count; those builds are simply
# unnumbered rather than wrong.
if COUNT=$(git rev-list --count HEAD 2>/dev/null); then
    :
else
    COUNT=0
fi

BASE="${MARKETING_VERSION:-0.0}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${BASE}.${COUNT}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${COUNT}" "$PLIST"
