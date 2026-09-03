XCODEPROJ := PaneRail.xcodeproj
SCHEME    := PaneRail
DERIVED   := build
DEBUG_APP := $(DERIVED)/Build/Products/Debug/PaneRail.app
BUNDLE_ID := dev.kafeg.panerail

# macOS ties an Accessibility grant to the code signature, so ad-hoc builds
# lose the permission on every rebuild. When the local development certificate
# exists (see Scripts/create-dev-certificate.sh) it is used instead, and the
# grant survives. CI has no such certificate and falls back to ad-hoc.
DEV_IDENTITY := PaneRail Dev
SIGN_IDENTITY := $(shell security find-identity -v -p codesigning 2>/dev/null \
	| grep -q "$(DEV_IDENTITY)" && echo "$(DEV_IDENTITY)" || echo "-")
XCODEFLAGS := -project $(XCODEPROJ) -scheme $(SCHEME) -derivedDataPath $(DERIVED) \
	CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)"

.PHONY: help generate build test run demo preview icons dev-certificate package install clean reset-permission

help:
	@echo "make build             Build the Debug app"
	@echo "make test              Run the unit tests"
	@echo "make run               Build and launch"
	@echo "make demo              Launch with scripted windows, no permission needed"
	@echo "make preview           Re-render the README screenshots"
	@echo "make icons             Rebuild AppIcon.icns from Assets/icon.svg"
	@echo "make package           Build Release and zip it into dist/"
	@echo "make install           Build Release and update /Applications in place"
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

preview: build
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-preview docs/rail-light.png
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-preview docs/rail-dark.png --dark
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-settings docs/settings-light.png
	$(DEBUG_APP)/Contents/MacOS/PaneRail --render-settings docs/settings-dark.png --dark
	@rm -f default.profraw

icons:
	./Scripts/generate-icons.sh

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
