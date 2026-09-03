XCODEPROJ := PaneRail.xcodeproj
SCHEME    := PaneRail
DERIVED   := build
DEBUG_APP := $(DERIVED)/Build/Products/Debug/PaneRail.app
BUNDLE_ID := dev.kafeg.panerail

.PHONY: help generate build test run demo preview icons release package clean reset-permission

help:
	@echo "make build             Build the Debug app"
	@echo "make test              Run the unit tests"
	@echo "make run               Build and launch"
	@echo "make demo              Launch with scripted windows, no permission needed"
	@echo "make preview           Re-render the README screenshots"
	@echo "make icons             Rebuild AppIcon.icns from Assets/icon.svg"
	@echo "make package           Build Release and zip it into dist/"
	@echo "make reset-permission  Forget the Accessibility grant for this bundle id"
	@echo "make clean             Remove build output and the generated project"

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) build

test: generate
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) test

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

package: generate
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration Release -derivedDataPath $(DERIVED) build
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
