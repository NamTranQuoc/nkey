import CoreGraphics
import Foundation

final class EventTapManager {
    typealias Handler = (CGEventTapProxy, CGEvent) -> CGEvent?

    private let handler: Handler
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask = [
            CGEventType.keyDown,
            CGEventType.keyUp,
            CGEventType.flagsChanged
        ].reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            AppLog.input.error("Unable to create event tap. Input Monitoring and Accessibility permissions may be missing.")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        AppLog.input.info("Event tap started")
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        eventTap = nil
        runLoopSource = nil
    }

    private func enable() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            manager.enable()
            return Unmanaged.passUnretained(event)
        }

        guard let returnedEvent = manager.handler(proxy, event) else {
            return nil
        }

        return Unmanaged.passUnretained(returnedEvent)
    }
}
