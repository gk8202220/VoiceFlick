# VoiceFlick

VoiceFlick is a native macOS SwiftUI app that uses local camera gestures and mouth-open detection to control macOS dictation. It can start dictation, stop dictation, press Return, and clear the current input field through accessibility keyboard events.

## Features

- Built-in Vision gestures: closed fist, pointing, Victory, thumbs up, wave, and mouth open.
- Configurable per-gesture enable switches.
- Custom gesture slots with local template matching.
- Mouth-open dictation start with configurable confidence threshold.
- Microphone dBFS silence detection while dictation is active.
- Action log panel showing when gestures triggered actions.
- Low-power defaults with hidden camera preview.

## Permissions

VoiceFlick needs:

- Camera: local hand and mouth landmark detection.
- Microphone: dBFS level only, used to detect silence while dictation is active. Audio is not recorded or saved.
- Accessibility: sends right Option, Return, Command-A, and Delete keyboard events.

## Development

```sh
swift test
swift build
```

For local app bundle launch:

```sh
./script/build_and_run.sh
```

Runtime logs are stored under:

```text
~/Library/Application Support/VoiceFlick/runtime.log
```
