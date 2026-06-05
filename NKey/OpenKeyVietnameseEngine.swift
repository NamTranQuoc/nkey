import CoreGraphics
import Foundation

struct OpenKeyVietnameseResult {
    let shouldConsumeEvent: Bool
    let replacementCount: Int
    let replacementText: String
}

final class OpenKeyVietnameseEngine {
    init() {
        OpenKeyBridgeInitialize()
    }

    func reset() {
        OpenKeyBridgeReset()
    }

    func processKeyDown(keyCode: CGKeyCode, typedText: String, flags: CGEventFlags) -> OpenKeyVietnameseResult {
        let result = OpenKeyBridgeProcessKey(
            UInt16(keyCode),
            flags.contains(.maskShift),
            flags.contains(.maskAlphaShift),
            hasOtherControlKey(flags)
        )

        return OpenKeyVietnameseResult(
            shouldConsumeEvent: result.handled,
            replacementCount: Int(result.replacementCount),
            replacementText: String(cString: result.replacementText)
        )
    }

    private func hasOtherControlKey(_ flags: CGEventFlags) -> Bool {
        flags.contains(.maskCommand) ||
            flags.contains(.maskControl) ||
            flags.contains(.maskAlternate) ||
            flags.contains(.maskSecondaryFn) ||
            flags.contains(.maskNumericPad) ||
            flags.contains(.maskHelp)
    }
}
