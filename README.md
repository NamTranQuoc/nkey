# NKey

NKey is a lightweight macOS menu bar utility for switching between English and Vietnamese input modes. English mode can show local autocomplete suggestions powered by Apple's `NSSpellChecker`, and Vietnamese mode uses the vendored OpenKey engine.

## Install And Use

Download the latest `.dmg` installer from [NKey Releases](https://github.com/NamTranQuoc/nkey/releases/latest).

### Install

1. Open the downloaded `NKey.dmg` file.
2. Drag `NKey.app` into the `Applications` folder.
3. Open `NKey.app` from `Applications`.
4. If macOS blocks the first launch, open `System Settings -> Privacy & Security`, scroll to the security message, and choose `Open Anyway`.

### Required Permissions

NKey needs these macOS permissions:

- `Accessibility`: allows NKey to read caret position and automate text replacement.
- `Input Monitoring`: allows NKey to listen for keyboard events and mode toggle shortcuts.

To grant permissions:

1. Open `System Settings -> Privacy & Security`.
2. Open `Accessibility` and enable `NKey`.
3. Open `Input Monitoring` and enable `NKey`.
4. Restart NKey after changing permissions.

You can also use `Open Privacy Settings` from the NKey menu to jump to the relevant settings pages.

### If macOS Says The App Is Damaged

If macOS shows `"NKey" is damaged and can't be opened`, remove the quarantine flag after moving the app to `Applications`:

```sh
xattr -dr com.apple.quarantine /Applications/NKey.app
```

Then open `NKey.app` again. This is only needed for unsigned or non-notarized local releases.

### Main Features

- The menu bar item shows the current mode as `EN` or `VI`.
- Press `Right Command` or `Ctrl+Space` to switch between English and Vietnamese.
- English mode can show up to three local suggestion results after typing at least two letters, and next-word suggestions after pressing Space.
- Use the `Suggestion List` menu checkbox to turn the suggestion list on or off.
- Use `Shift+Space` to commit the highlighted suggestion.
- Use `Shift+Up Arrow` / `Shift+Left Arrow` to select the previous suggestion.
- Use `Shift+Down Arrow` / `Shift+Right Arrow` to select the next suggestion.
- Use `Escape` to dismiss suggestions.
- Use `Restart` from the menu to restart the keyboard event tap after permission changes.
- Use `Quit NKey` to exit the app.

Vietnamese mode uses OpenKey's GPL-3.0 Telex engine.

## Build And Run From Source

### Requirements

- macOS 13 or newer.
- Xcode 14 or newer.
- The same `Accessibility` and `Input Monitoring` permissions described above.

### Version

Update `MARKETING_VERSION` in `Config/Version.xcconfig` before creating a new release.

### Run With Xcode

1. Open `NKey.xcodeproj` in Xcode.
2. Select the `NKey` scheme.
3. Build with `Product -> Build` or `Cmd+B`.
4. Run with `Product -> Run` or `Cmd+R`.
5. Grant the required permissions if macOS prompts for them.
6. Restart the app after granting permissions.

### Build With Command Line Tools

You can also build a local app bundle from the repository root:

```sh
rm -rf build/NKey.app
mkdir -p build/NKey.app/Contents/MacOS
cp NKey/Info.plist build/NKey.app/Contents/Info.plist

xcrun swiftc NKey/*.swift NKey/OpenKeyBridge.mm \
  ThirdParty/OpenKeyEngine/engine/Engine.cpp \
  ThirdParty/OpenKeyEngine/engine/Vietnamese.cpp \
  ThirdParty/OpenKeyEngine/engine/Macro.cpp \
  ThirdParty/OpenKeyEngine/engine/SmartSwitchKey.cpp \
  ThirdParty/OpenKeyEngine/engine/ConvertTool.cpp \
  -import-objc-header NKey/NKey-Bridging-Header.h \
  -I ThirdParty/OpenKeyEngine/engine \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework Carbon \
  -lc++ \
  -o build/NKey.app/Contents/MacOS/NKey

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable NKey" build/NKey.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleName NKey" build/NKey.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.local.NKey" build/NKey.app/Contents/Info.plist

chmod +x build/NKey.app/Contents/MacOS/NKey
codesign --force --deep --sign - build/NKey.app
open build/NKey.app
```