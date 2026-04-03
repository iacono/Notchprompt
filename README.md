# Notchprompt

A macOS teleprompter app that drops down from the notch on MacBook Pro. Manage scripts, control scrolling with voice detection, and present seamlessly — all from your menu bar.

## Features

- **Notch-integrated UI** — the prompter panel drops down from the MacBook Pro notch with a spring animation and concave corner fills that blend into the bezel
- **Voice-activated scrolling** — uses your microphone to detect speech and automatically scroll the text while you talk
- **Double-tap spacebar** — play/pause scrolling from any app via a global keyboard shortcut (requires Accessibility permission)
- **Adjustable scroll speed** — fine-tune how fast the text moves
- **Countdown timer** — optional on-screen timer to track your presentation time
- **Script management** — create, edit, and switch between multiple scripts from the settings window or menu bar
- **Menu bar app** — runs as a lightweight menu bar item without cluttering your dock

## Requirements

- macOS 13.0 (Ventura) or later
- MacBook with a notch (works on non-notch Macs too, panel appears at top-center of screen)
- Swift 5.9+

## Install

### Download

Grab the latest `Notchprompt.dmg` from the [Releases](https://github.com/iacono/Notchprompt/releases) page or from the repo directly. Open the DMG and drag Notchprompt to your Applications folder.

### Build from source

```bash
git clone https://github.com/iacono/Notchprompt.git
cd Notchprompt
./build-app.sh
```

This compiles a release build with Swift Package Manager and creates `NotchPrompter.app`. To install:

```bash
cp -r NotchPrompter.app /Applications/
```

Or just run it directly:

```bash
open NotchPrompter.app
```

## Usage

1. **Launch** — Notchprompt appears as an icon in your menu bar
2. **Add scripts** — Click the menu bar icon > Settings to create and manage your scripts
3. **Select a script** — Pick a script from the menu bar dropdown; the prompter panel slides down from the notch
4. **Start scrolling** — Double-tap the spacebar, or use the menu bar Play/Pause option
5. **Voice mode** — While scrolling is active, the app listens for your voice and scrolls when you speak

## Permissions

Notchprompt requests two system permissions:

- **Microphone** — for voice-activated scrolling (speech detection)
- **Accessibility** — for the global double-tap spacebar shortcut (optional — you can use menu bar controls instead)

## Project Structure

```
NotchPrompter/
  App/              # App entry point and AppDelegate
  MenuBar/          # Menu bar icon and menu management
  Models/           # Script, ScriptStore, AppSettings
  Services/         # ScrollEngine, VoiceActivityDetector, TimerService, KeyboardMonitor
  Views/            # TeleprompterView, SettingsView, ScrollableTextView
  Windows/          # TeleprompterPanel (NSPanel subclass)
  Resources/        # Info.plist, entitlements, app icon assets
Package.swift       # Swift Package Manager manifest
build-app.sh        # Build script that creates the .app bundle
```

## License

Copyright 2026 Marco. All rights reserved.
