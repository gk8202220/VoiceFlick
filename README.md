# VoiceFlick

VoiceFlick is a native macOS SwiftUI app that uses local camera gestures and mouth-open detection to control macOS dictation and text editing. It can start dictation, stop dictation, copy, paste, press Return, and clear the current input field through accessibility keyboard events.

## Features

- Built-in Vision gestures: closed fist, pointing, Victory, thumbs up, wave/open palm, and mouth open.
- Grip sequence: open palm to closed fist copies, then releasing the fist pastes.
- Configurable per-gesture enable switches.
- On-demand custom gestures with local template matching.
- Mouth-open dictation start with configurable confidence threshold and hold duration.
- Microphone dBFS silence detection while dictation is active.
- Action log panel showing when gestures triggered actions.
- Low-power defaults with hidden camera preview.

## Permissions

VoiceFlick needs:

- Camera: local hand and mouth landmark detection.
- Microphone: dBFS level only, used to detect silence while dictation is active. Audio is not recorded or saved.
- Accessibility: sends right Option, Return, Command-A, Command-C, Command-V, and Delete keyboard events.

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
