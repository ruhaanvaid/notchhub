PROJECT := NotchHub.xcodeproj
SCHEME  := NotchHub
# ".noindex" keeps development builds out of Spotlight and Launchpad.
DERIVED := build/xcode.noindex
APP_DEBUG   := $(DERIVED)/Build/Products/Debug/NotchHub.app
APP_RELEASE := $(DERIVED)/Build/Products/Release/NotchHub.app
DIST    := build/dist
VERSION := $(shell sed -nE 's/^ *MARKETING_VERSION: *"([^"]+)".*/\1/p' project.yml)
ARCH    := $(shell uname -m)

.PHONY: gen build release run install dist clean

gen:
	@command -v xcodegen >/dev/null || { echo "xcodegen not found: run 'brew install xcodegen'"; exit 1; }
	xcodegen generate

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination "platform=macOS,arch=$(ARCH)" -derivedDataPath $(DERIVED) build

# Universal (Apple silicon + Intel) Release build.
release: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination "generic/platform=macOS" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
		-derivedDataPath $(DERIVED) build

run: build
	-pkill -x NotchHub
	open $(APP_DEBUG)

install: release
	-pkill -x NotchHub
	rm -rf /Applications/NotchHub.app
	cp -R $(APP_RELEASE) /Applications/
	open /Applications/NotchHub.app

# Zip for a GitHub release: build/dist/NotchHub-<version>.zip
dist: release
	rm -rf $(DIST) && mkdir -p $(DIST)
	codesign --verify --deep --strict $(APP_RELEASE)
	ditto -c -k --sequesterRsrc --keepParent $(APP_RELEASE) $(DIST)/NotchHub-$(VERSION).zip
	cd $(DIST) && shasum -a 256 NotchHub-$(VERSION).zip | tee NotchHub-$(VERSION).zip.sha256

clean:
	rm -rf $(DERIVED) $(PROJECT)
