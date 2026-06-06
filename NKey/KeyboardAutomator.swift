import CoreGraphics
import Foundation

final class KeyboardAutomator {
    private static let syntheticEventMarker: Int64 = 0x4E4B6579
    private let source = CGEventSource(stateID: .hidSystemState)

    func isSynthetic(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker
    }

    func commit(
        _ completion: String,
        replacingCharacterCount replacementCount: Int,
        proxy: CGEventTapProxy? = nil,
        stabilizeAutocomplete: Bool = false
    ) {
        let committedText = completion
        guard replacementCount >= 0, !committedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        replaceText(
            committedText,
            replacingCharacterCount: replacementCount,
            proxy: proxy,
            stabilizeAutocomplete: stabilizeAutocomplete
        )
        AppLog.automation.debug("Committed suggestion with replacement count \(replacementCount)")
    }

    func replaceText(
        _ text: String,
        replacingCharacterCount replacementCount: Int,
        proxy: CGEventTapProxy? = nil,
        stabilizeAutocomplete: Bool = false,
        postsTextAsSingleEvent: Bool = false
    ) {
        guard replacementCount >= 0 else { return }

        var deleteCount = replacementCount
        if stabilizeAutocomplete, replacementCount > 0 {
            typeText("\u{202F}", proxy: proxy)
            deleteCount += 1
        }

        for _ in 0..<deleteCount {
            postKeyStroke(keyCode: KeyCode.delete, proxy: proxy)
        }

        if !text.isEmpty {
            if postsTextAsSingleEvent {
                typeTextAsSingleEvent(text, proxy: proxy)
            } else {
                typeText(text, proxy: proxy)
            }
        }
    }

    private func postKeyStroke(keyCode: CGKeyCode, flags: CGEventFlags = [], proxy: CGEventTapProxy? = nil) {
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags
        markSynthetic(keyDown)
        markSynthetic(keyUp)
        post(keyDown, proxy: proxy)
        post(keyUp, proxy: proxy)
    }

    private func typeText(_ text: String, proxy: CGEventTapProxy? = nil) {
        for scalar in text.unicodeScalars {
            let units = Array(String(scalar).utf16)

            guard
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                continue
            }

            markSynthetic(keyDown)
            markSynthetic(keyUp)
            units.withUnsafeBufferPointer { buffer in
                keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            }
            post(keyDown, proxy: proxy)
            post(keyUp, proxy: proxy)
        }
    }

    private func typeTextAsSingleEvent(_ text: String, proxy: CGEventTapProxy? = nil) {
        let units = Array(text.utf16)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else {
            return
        }

        markSynthetic(keyDown)
        markSynthetic(keyUp)
        units.withUnsafeBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        post(keyDown, proxy: proxy)
        post(keyUp, proxy: proxy)
    }

    private func post(_ event: CGEvent, proxy: CGEventTapProxy?) {
        if let proxy {
            event.tapPostEvent(proxy)
        } else {
            event.post(tap: .cghidEventTap)
        }
    }

    private func markSynthetic(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
    }
}
