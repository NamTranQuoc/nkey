import AppKit
import ApplicationServices

final class CaretPositionProvider {
    func caretScreenPosition() -> CGPoint? {
        guard AXIsProcessTrusted() else { return nil }

        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success, let focusedValue else {
            return nil
        }

        let focusedElement = focusedValue as! AXUIElement
        var selectedRangeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        ) == .success, let selectedRangeValue else {
            return nil
        }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRangeValue,
            &boundsValue
        ) == .success, let boundsValue else {
            return nil
        }

        let axBounds = boundsValue as! AXValue
        var bounds = CGRect.zero

        guard AXValueGetType(axBounds) == .cgRect,
              AXValueGetValue(axBounds, .cgRect, &bounds) else {
            return nil
        }

        return CGPoint(x: bounds.minX, y: bounds.maxY + 6)
    }

    func fallbackScreenPosition() -> CGPoint {
        let mouseLocation = NSEvent.mouseLocation
        return CGPoint(x: mouseLocation.x + 8, y: mouseLocation.y - 48)
    }
}
