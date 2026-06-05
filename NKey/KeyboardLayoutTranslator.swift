import Carbon.HIToolbox
import CoreGraphics
import Foundation

final class KeyboardLayoutTranslator {
    private var deadKeyState: UInt32 = 0

    func text(for event: CGEvent, keyCode: CGKeyCode) -> String {
        if hasTextBlockingModifier(event.flags) {
            return ""
        }

        let directText = event.keyboardText
        if !directText.isEmpty {
            return directText
        }

        return translatedText(for: keyCode, flags: event.flags)
    }

    private func translatedText(for keyCode: CGKeyCode, flags: CGEventFlags) -> String {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPointer = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return ""
        }

        let layoutData = unsafeBitCast(layoutDataPointer, to: CFData.self)
        guard let layoutBytes = CFDataGetBytePtr(layoutData) else {
            return ""
        }

        let keyboardLayout = layoutBytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
        let modifiers = carbonModifiers(from: flags)
        let keyboardType = UInt32(LMGetKbdType())
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        var localDeadKeyState = deadKeyState

        let status = UCKeyTranslate(
            keyboardLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            modifiers,
            keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &localDeadKeyState,
            characters.count,
            &length,
            &characters
        )

        guard status == noErr, length > 0 else {
            return ""
        }

        deadKeyState = localDeadKeyState
        return String(utf16CodeUnits: characters, count: length)
    }

    private func carbonModifiers(from flags: CGEventFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if flags.contains(.maskShift) {
            modifiers |= UInt32(shiftKey >> 8)
        }

        if flags.contains(.maskAlphaShift) {
            modifiers |= UInt32(alphaLock >> 8)
        }

        return modifiers
    }

    private func hasTextBlockingModifier(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand) ||
            flags.contains(.maskControl) ||
            flags.contains(.maskAlternate)
    }
}

extension CGEvent {
    var keyboardText: String {
        var actualLength = 0
        var characters = [UniChar](repeating: 0, count: 8)

        keyboardGetUnicodeString(
            maxStringLength: characters.count,
            actualStringLength: &actualLength,
            unicodeString: &characters
        )

        guard actualLength > 0 else { return "" }
        return String(utf16CodeUnits: characters, count: actualLength)
    }
}
