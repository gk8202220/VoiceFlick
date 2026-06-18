import ApplicationServices
import CoreGraphics
import Foundation

final class KeyboardActionService {
    private let source = CGEventSource(stateID: .hidSystemState)
    private let rightOptionKey: CGKeyCode = 0x3D
    private let returnKey: CGKeyCode = 0x24
    private let aKey: CGKeyCode = 0x00
    private let cKey: CGKeyCode = 0x08
    private let vKey: CGKeyCode = 0x09
    private let deleteKey: CGKeyCode = 0x33
    private var lastAccessibilityPrompt = Date.distantPast

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityTrust() {
        let now = Date()
        guard now.timeIntervalSince(lastAccessibilityPrompt) >= 5 else {
            DiagnosticsLogger.shared.append("accessibility prompt skipped cooldown")
            return
        }
        lastAccessibilityPrompt = now
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        DiagnosticsLogger.shared.append("accessibility prompt requested")
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func perform(_ action: ActionMapping) {
        DiagnosticsLogger.shared.append("perform requested \(action.rawValue) trusted=\(isAccessibilityTrusted)")
        guard action != .none else { return }
        guard isAccessibilityTrusted else {
            requestAccessibilityTrust()
            return
        }

        switch action {
        case .startDictation:
            DiagnosticsLogger.shared.append("keySequence rightOptionDoubleTap action=startDictation")
            doubleTapRightOption()
        case .stopDictation:
            DiagnosticsLogger.shared.append("keySequence rightOptionDoubleTap action=stopDictation")
            doubleTapRightOption()
        case .pressReturn:
            DiagnosticsLogger.shared.append("keySequence return action=pressReturn")
            tapKey(returnKey)
        case .clearInput:
            DiagnosticsLogger.shared.append("keySequence commandADelete action=clearInput")
            clearFocusedInput()
        case .copyClipboard:
            DiagnosticsLogger.shared.append("keySequence commandC action=copyClipboard")
            tapKey(cKey, flags: .maskCommand)
        case .pasteClipboard:
            DiagnosticsLogger.shared.append("keySequence commandV action=pasteClipboard")
            tapKey(vKey, flags: .maskCommand)
        case .none:
            break
        }
    }

    private func doubleTapRightOption() {
        tapModifierKey(rightOptionKey, flags: .maskAlternate)
        Thread.sleep(forTimeInterval: 0.18)
        tapModifierKey(rightOptionKey, flags: .maskAlternate)
    }

    private func clearFocusedInput() {
        tapKey(aKey, flags: .maskCommand)
        Thread.sleep(forTimeInterval: 0.05)
        tapKey(deleteKey)
    }

    private func tapKey(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }

    private func tapModifierKey(_ key: CGKeyCode, flags: CGEventFlags) {
        postModifierKey(key, flags: flags)
        Thread.sleep(forTimeInterval: 0.06)
        postModifierKey(key, flags: [])
    }

    private func postModifierKey(_ key: CGKeyCode, flags: CGEventFlags) {
        guard let event = CGEvent(source: source) else { return }
        event.type = .flagsChanged
        event.flags = flags
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(key))
        event.post(tap: .cghidEventTap)
    }
}
