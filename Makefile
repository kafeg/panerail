XCODEPROJ := PaneRail.xcodeproj
SCHEME    := PaneRail
DERIVED   := build
DEBUG_APP := $(DERIVED)/Build/Products/Debug/PaneRail.app
BUNDLE_ID := dev.kafeg.panerail
# The app the README screenshots are taken against.
APP_ID ?= com.microsoft.VSCode

# macOS ties an Accessibility grant to the code signature, so ad-hoc builds
# lose the permission on every rebuild. When the local development certificate
# exists (see Scripts/create-dev-certificate.sh) it is used instead, and the
# grant survives. CI has no such certificate and falls back to ad-hoc.
DEV_IDENTITY := PaneRail Dev
SIGN_IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null \
	| grep -q "$(DEV_IDENTITY)" && echo "$(DEV_IDENTITY)" || echo "-")
XCODEFLAGS := -project $(XCODEPROJ) -scheme $(SCHEME) -derivedDataPath $(DERIVED) \
	CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)"

.PHONY: help generate build test run demo preview preview-rail icons version dev-certificate package install clean reset-permission

help:
	@echo "make build             Build the Debug app"
	@echo "make test              Run the unit tests"
	@echo "make run               Build and launch"
	@echo "make demo              Launch with scripted windows, no permission needed"
	@echo "make preview           Re-render the settings screenshots"
	@echo "make preview-rail      Re-render the rail screenshots against a running app"
	@echo "make icons             Rebuild AppIcon.icns from Assets/icon.svg"
	@echo "make package           Build Release and zip it into dist/"
	@echo "make install           Build Release and update /Applications in place"
	@echo "make version           Print the version the next build will carry"
	@echo "make dev-certificate   Create the signing certificate that keeps the Accessibility grant"
	@echo "make reset-permission  Forget the Accessibility grant for this bundle id"
	@echo "make clean             Remove build output and the generated project"

generate:
	xcodegen generate

build: generate
	xcodebuild $(XCODEFLAGS) -configuration Debug build

test: generate
	xcodebuild $(XCODEFLAGS) -configuration Debug test

run: build
	@pkill -f "PaneRail.app/Contents/MacOS/PaneRail" || true
	open $(DEBUG_APP)

demo: build
	@pkill -f "PaneRail.app/Contents/MacOS/PaneRail" || true
	open $(DEBUG_APP) --args --demo

# The settings shots render from scripted state. The rail shots are taken
# against a real running app so the README shows its actual icon, which means
# they need the installed, permitted build and whatever app you point them at.
preview: build
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-settings docs/settings-light.png
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-settings docs/settings-dark.png --dark
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-settings docs/advanced-light.png --advanced
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-settings docs/advanced-dark.png --advanced --dark
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-strip docs/strip-light.png
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-strip docs/strip-dark.png --dark
	@rm -f default.profraw

preview-rail: install
	open -n /Applications/PaneRail.app --args --render-live $(APP_ID) docs/rail-light.png
	sleep 6
	open -n /Applications/PaneRail.app --args --render-live $(APP_ID) docs/rail-dark.png --dark
	sleep 6

icons:
	./Scripts/generate-icons.sh

# What the next build will call itself, so a tag can be named to match.
version:
	@printf '%s.%s\n' \
		"$$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)" \
		"$$(git rev-list --count HEAD)"

dev-certificate:
	./Scripts/create-dev-certificate.sh

# Updates the bundle in place. Deleting it first would drop the Accessibility
# grant: macOS forgets the entry when the app disappears, however stable the
# signature is.
install: package
	@pkill -f "PaneRail.app/Contents/MacOS/PaneRail" || true
	@mkdir -p /Applications/PaneRail.app
	rsync -a --delete $(DERIVED)/Build/Products/Release/PaneRail.app/ /Applications/PaneRail.app/
	@echo "Installed to /Applications/PaneRail.app"

package: generate
	xcodebuild $(XCODEFLAGS) -configuration Release build
	mkdir -p dist
	ditto -c -k --sequesterRsrc --keepParent \
		$(DERIVED)/Build/Products/Release/PaneRail.app dist/PaneRail.zip
	@echo "Wrote dist/PaneRail.zip"

# macOS ties an Accessibility grant to the app's code signature, so every local
# rebuild looks like a different app. Run this when the rail stops appearing
# after a rebuild, then grant access again.
reset-permission:
	tccutil reset Accessibility $(BUNDLE_ID) || true

clean:
	rm -rf $(DERIVED) dist $(XCODEPROJ)
