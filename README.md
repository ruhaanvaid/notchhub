# NotchHub

A free, open-source macOS menu-bar utility that turns the MacBook notch into a Dynamic Island-style control strip.

- **Volume and brightness HUD**: replaces Apple's overlay with one that grows out of the notch. Volume uses Apple's 16-step scale (16 segments, with quarter steps on Shift+Option); brightness shows a level bar and percentage.
- **Hover panel**: now playing (Music, Spotify, and YouTube in Safari, Chrome, Arc, Brave or Edge), a volume slider, an audio output picker, Keep Awake and Do Not Disturb buttons.
- **File shelf**: drag files onto the notch to park them, then drag them back out to drop them anywhere.
- **Works without a notch**: shows a small pill at the top of the main display, either alongside the notch when you use an external monitor or on its own on Macs without one.
- Hides while a full-screen app covers the screen.

Requires macOS 14 or later, on Apple silicon or Intel. No third-party dependencies.

## Download and install

1. Download **NotchHub-x.y.z.zip** from the [latest release](https://github.com/ruhaanvaid/notchhub/releases/latest).
2. Unzip it and drag **NotchHub.app** into your **Applications** folder.
3. Open NotchHub. The first time, macOS says it can't verify the app. NotchHub is free and isn't notarized by Apple, which needs a paid developer account. To allow it:
   - Click **Done** (or **OK**) on the warning.
   - Open **System Settings › Privacy & Security** and scroll down to **Security**.
   - Next to "NotchHub was blocked…", click **Open Anyway**, confirm with Touch ID or your password, then click **Open**.

   You only need to do this once. If you're comfortable with Terminal, this does the same thing:

   ```sh
   xattr -dr com.apple.quarantine /Applications/NotchHub.app
   ```

4. NotchHub has no Dock icon. Look for it in the menu bar, and hover the notch (or the small pill at the top of your main display) to open the panel.
5. To replace Apple's volume and brightness overlay, NotchHub asks for one permission. Click **Open Settings** in its welcome window and switch NotchHub on, under **Accessibility** (macOS 14–26) or **Device Control and Data Access** (macOS 27 and later). Everything else works without it.
6. Optional: set up the [Do Not Disturb shortcuts](#do-not-disturb-setup), and turn on **Launch at login** in Settings.

**Updating:** from version 0.3.0 on, NotchHub checks GitHub once a day and shows a dot on its menu-bar icon when a new version is out (menu › **Update Available**, or **Check for Updates…** any time). Quit NotchHub, replace the app in Applications with the new download, and open it again. Your settings, shelf and permission carry over. Automatic checks can be turned off in Settings › Updates.

## Build from source

You need Xcode (with command-line tools) and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
```

Then, from the repository root:

```sh
make run       # generate the project, build Debug, and launch it
make build     # build only
make install   # build Release and copy it to /Applications (best for Launch at Login)
make dist      # universal Release build zipped into build/dist/ for a GitHub release
make clean     # remove build output and the generated project
```

The Xcode project is generated from `project.yml` and is not checked in. To work in Xcode, run `xcodegen generate` and open `NotchHub.xcodeproj`.

### Signing

No paid developer account is needed. By default the app is signed ad-hoc ("Sign to Run Locally"). That works, but every rebuild changes the code signature, so macOS forgets the Accessibility permission after each build.

For a permission that survives rebuilds, use a stable signing identity:

1. Create a self-signed certificate called **NotchHub Local Signing** in Keychain Access: **Keychain Access › Certificate Assistant › Create a Certificate…**, with Identity Type *Self-Signed Root* and Certificate Type *Code Signing*. It does not need to be trusted.
2. Let `codesign` use the key without a prompt (it asks for your login password):

   ```sh
   security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
     -l "NotchHub Local Signing" ~/Library/Keychains/login.keychain-db
   ```

3. Copy `Config/Signing.local.xcconfig.example` to `Config/Signing.local.xcconfig` (git ignores it) and uncomment the `CODE_SIGN_IDENTITY` line.

You can also use a free Apple ID "Personal Team" instead; see the example file.

## Permissions

| Permission | Needed for | Where to grant it |
|---|---|---|
| Accessibility | Catching the volume and brightness keys so Apple's overlay doesn't appear | System Settings › Privacy & Security › **Accessibility** (macOS 14–26) or **Device Control and Data Access** (macOS 27+) |
| Automation (Music, Spotify, your browser) | Showing and controlling what's playing | macOS asks the first time; change it later under Privacy & Security › Automation |

NotchHub opens an onboarding window on first launch, and **Permissions…** in the menu-bar icon reopens it. Everything except the HUD replacement works without Accessibility.

NotchHub only swallows a key when it can fully handle it. If your output has no software volume (some HDMI and DisplayPort devices), or brightness can't be controlled, the key goes to macOS untouched. Option+Volume (open Sound settings) and other modifier combinations always pass through. Shift+Option gives fine 1/64 steps, as in macOS.

**If the permission doesn't take:** an old entry may be pinned to a previous signature. Remove it:

```sh
tccutil reset Accessibility com.notchhub.app
```

Then grant it again from the onboarding window.

**If nothing appears at all:** check Screen Time. Under Downtime or App Limits, macOS hides the windows of apps that aren't allowed. Add NotchHub to System Settings › Screen Time › **Always Allowed**.

## YouTube controls

NotchHub finds YouTube and YouTube Music tabs in Safari, Chrome, Arc, Brave and Edge, and shows the video's title and thumbnail. (Firefox can't be scripted this way.) To also see whether a video is playing and control it from the notch, turn on **Allow JavaScript from Apple Events** in your browser:

- **Chrome, Arc, Brave, Edge:** View › Developer › Allow JavaScript from Apple Events
- **Safari:** Settings › Advanced › Show features for web developers, then Develop › Allow JavaScript from Apple Events

This option lets any app you've allowed to control that browser run scripts in its pages, so only turn it on if you're comfortable with that. NotchHub only runs a short script on YouTube tabs, to read the title and play state and press play, pause or next. You can turn browser detection off in Settings › Panel.

## Do Not Disturb setup

macOS has no public API for Focus, so NotchHub runs two Shortcuts that you create once:

1. Open **Shortcuts** and create a new shortcut.
2. Add the **Set Focus** action and set it to turn **Do Not Disturb** **On**, "Until Turned Off".
3. Name it exactly **NotchHub Focus On**.
4. Create a second shortcut that turns Do Not Disturb **Off**, named exactly **NotchHub Focus Off**.

Settings › Do Not Disturb Setup shows whether both were found. NotchHub can't read the current Focus state, so the button shows what NotchHub last set. If you change Focus elsewhere, tap the button twice to resync.

## Settings

Open them from the menu-bar icon › **Settings…**:

- Launch at login, the main-display pill, and hiding during full-screen apps
- Replace the volume and/or brightness overlay, and how long the HUD stays up (0.5–5 s)
- Show or hide each panel section: now playing, the volume slider and output picker, Keep Awake, Do Not Disturb, and the file shelf

## How it works

- **Notch panel**: a borderless, non-activating `NSPanel` above the menu bar. It never takes focus. It ignores the mouse except inside the visible shape, so menu-bar items next to the notch stay clickable. Geometry comes from `NSScreen.safeAreaInsets` and the auxiliary top areas.
- **HUD**: an active `CGEventTap` on `NSSystemDefined` events (subtype 8). Volume is set through CoreAudio on the default output device. Brightness uses the private DisplayServices framework, loaded with `dlopen` behind a protocol, with a pass-through fallback.
- **Now playing**: AppleScript to Music and Spotify, driven by their playback notifications. YouTube is found by listing browser tabs; with JavaScript from Apple Events on, a page script reads `navigator.mediaSession` and the `<video>` element. Scripts run on a background queue, and polling happens only while the panel is open or something is playing. MediaRemote isn't used.
- **Keep Awake**: an `IOPMAssertion` that prevents display sleep. A cyan dot beside the notch shows while it's on.
- **Shelf**: stores bookmarks, not copies, in `~/Library/Application Support/NotchHub/shelf.json`. Moved files are followed; deleted or trashed ones are dropped.

### Design snapshots

`Tools/snapshots.sh [output-dir]` renders the panel, the HUD in its different states, and the Settings window to PNGs with sample data. Use it to review UI changes without driving the real app.

## License

MIT. See [LICENSE](LICENSE).
