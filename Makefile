PROJECT := NotchHub.xcodeproj
SCHEME  := NotchHub
DERIVED := build
APP_DEBUG   := $(DERIVED)/Build/Products/Debug/NotchHub.app
APP_RELEASE := $(DERIVED)/Build/Products/Release/NotchHub.app

.PHONY: gen build release run install clean

gen:
	@command -v xcodegen >/dev/null || { echo "xcodegen not found: run 'brew install xcodegen'"; exit 1; }
	xcodegen generate

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination "platform=macOS,arch=arm64" -derivedDataPath $(DERIVED) build

release: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination "platform=macOS,arch=arm64" -derivedDataPath $(DERIVED) build

run: build
	-pkill -x NotchHub
	open $(APP_DEBUG)

install: release
	-pkill -x NotchHub
	rm -rf /Applications/NotchHub.app
	cp -R $(APP_RELEASE) /Applications/
	open /Applications/NotchHub.app

clean:
	rm -rf $(DERIVED) $(PROJECT)
