import AppKit
import ApplicationServices
import CoreGraphics

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let modeState = InputModeState()
    private let suggestionEngine = SuggestionEngine()
    private let suggestionPanel = SuggestionPanel()
    private let caretPositionProvider = CaretPositionProvider()
    private let keyboardTranslator = KeyboardLayoutTranslator()
    private let keyboardAutomator = KeyboardAutomator()
    private let vietnameseEngine = OpenKeyVietnameseEngine()
    private let statusItemController = StatusItemController()

    private var eventTapManager: EventTapManager?
    private var isSuggestionListEnabled = true
    private var rightCommandWasDown = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureModeState()
        configureStatusItem()
        requestRequiredPermissionsIfNeeded()
        updatePermissionStatus()
        startEventTap()
        logPermissionState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventTapManager?.stop()
    }

    private func configureModeState() {
        modeState.onChange = { [weak self] mode in
            guard let self else { return }
            self.suggestionEngine.reset()
            self.vietnameseEngine.reset()
            self.suggestionPanel.hide()
            self.statusItemController.update(mode: mode)
            AppLog.app.info("Input mode changed to \(mode.rawValue)")
        }
    }

    private func configureStatusItem() {
        statusItemController.onToggle = { [weak self] in
            self?.modeState.toggle()
        }

        statusItemController.onToggleSuggestionList = { [weak self] in
            self?.toggleSuggestionList()
        }

        statusItemController.onRestartEventTap = { [weak self] in
            self?.restartEventTap()
        }

        statusItemController.onOpenPrivacySettings = {
            Self.openPrivacySettings()
        }

        statusItemController.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func startEventTap() {
        eventTapManager = EventTapManager { [weak self] proxy, event in
            self?.handle(proxy: proxy, event: event) ?? event
        }

        if eventTapManager?.start() == false {
            AppLog.app.error("NKey started without an active event tap")
        }

        updatePermissionStatus()
        statusItemController.updateEventTap(isRunning: eventTapManager?.isRunning == true)
    }

    private func restartEventTap() {
        requestRequiredPermissionsIfNeeded()
        updatePermissionStatus()
        eventTapManager?.stop()
        startEventTap()
    }

    private func toggleSuggestionList() {
        isSuggestionListEnabled.toggle()
        statusItemController.updateSuggestionList(isEnabled: isSuggestionListEnabled)

        if !isSuggestionListEnabled {
            suggestionEngine.reset()
            suggestionPanel.hide()
        }
    }

    private func handle(proxy: CGEventTapProxy, event: CGEvent) -> CGEvent? {
        if keyboardAutomator.isSynthetic(event) {
            return event
        }

        let keyCode = CGKeyCode(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))

        switch event.type {
        case .flagsChanged:
            return handleFlagsChanged(event: event, keyCode: keyCode)
        case .keyDown:
            return handleKeyDown(proxy: proxy, event: event, keyCode: keyCode)
        default:
            return event
        }
    }

    private func handleFlagsChanged(event: CGEvent, keyCode: CGKeyCode) -> CGEvent? {
        guard keyCode == KeyCode.rightCommand else { return event }

        let rightCommandIsDown = event.flags.contains(.maskCommand)
        defer { rightCommandWasDown = rightCommandIsDown }

        guard rightCommandIsDown, !rightCommandWasDown else {
            return nil
        }

        modeState.toggle()
        return nil
    }

    private func handleKeyDown(proxy: CGEventTapProxy, event: CGEvent, keyCode: CGKeyCode) -> CGEvent? {
        if isControlSpace(event: event, keyCode: keyCode) {
            modeState.toggle()
            return nil
        }

        let typedText = keyboardTranslator.text(for: event, keyCode: keyCode)

        if modeState.current == .vietnamese {
            return handleVietnameseKeyDown(proxy: proxy, event: event, keyCode: keyCode, typedText: typedText)
        }

        guard isSuggestionListEnabled else {
            return event
        }

        if suggestionPanel.isVisible, handleSuggestionNavigation(proxy: proxy, event: event, keyCode: keyCode) {
            return nil
        }

        let suggestions = suggestionEngine.processKeyDown(
            keyCode: keyCode,
            characters: typedText
        )

        scheduleSuggestionPanelUpdate(suggestions)
        return event
    }

    private func handleVietnameseKeyDown(proxy _: CGEventTapProxy, event: CGEvent, keyCode: CGKeyCode, typedText: String) -> CGEvent? {
        suggestionEngine.reset()
        suggestionPanel.hide()

        let result = vietnameseEngine.processKeyDown(keyCode: keyCode, typedText: typedText, flags: event.flags)
        guard result.shouldConsumeEvent else {
            return event
        }

        let replacementText = result.replacementText
        let originalCharacterCount = max(typedText.count, 1)
        let replacementCount = result.replacementCount + originalCharacterCount
        let automator = keyboardAutomator

        DispatchQueue.main.async {
            automator.replaceText(
                replacementText,
                replacingCharacterCount: replacementCount,
                proxy: nil,
                postsTextAsSingleEvent: true
            )
        }

        return event
    }

    private func handleSuggestionNavigation(proxy: CGEventTapProxy, event: CGEvent, keyCode: CGKeyCode) -> Bool {
        let isShiftDown = event.flags.contains(.maskShift)

        if keyCode == KeyCode.escape {
            suggestionEngine.reset()
            suggestionPanel.hide()
            return true
        }

        guard isShiftDown else {
            return false
        }

        switch keyCode {
        case KeyCode.space:
            if let selectedSuggestion = suggestionPanel.selectedSuggestion {
                commitSuggestion(selectedSuggestion, proxy: proxy)
            }
            return false
        case KeyCode.downArrow, KeyCode.rightArrow:
            suggestionPanel.selectNext()
            return true
        case KeyCode.upArrow, KeyCode.leftArrow:
            suggestionPanel.selectPrevious()
            return true
        default:
            return false
        }
    }

    private func commitSuggestion(_ suggestion: String, proxy: CGEventTapProxy) {
        let replacementCount = suggestionEngine.currentPrefixLength
        suggestionEngine.reset()
        suggestionPanel.hide()
        keyboardAutomator.commit(
            suggestion,
            replacingCharacterCount: replacementCount,
            proxy: proxy,
            stabilizeAutocomplete: needsAutocompleteStabilization()
        )
    }

    private func scheduleSuggestionPanelUpdate(_ suggestions: [String]) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self else { return }

            guard self.isSuggestionListEnabled, self.modeState.current == .english else {
                self.suggestionPanel.hide()
                return
            }

            guard !suggestions.isEmpty else {
                self.suggestionPanel.hide()
                return
            }

            let position = self.caretPositionProvider.caretScreenPosition()
                ?? self.caretPositionProvider.fallbackScreenPosition()
            self.suggestionPanel.show(suggestions: suggestions, near: position)
        }
    }

    private func isControlSpace(event: CGEvent, keyCode: CGKeyCode) -> Bool {
        keyCode == KeyCode.space && event.flags.contains(.maskControl)
    }

    private func needsAutocompleteStabilization() -> Bool {
        guard let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }

        return bundleIdentifier == "com.google.Chrome" ||
            bundleIdentifier == "com.google.Chrome.canary" ||
            bundleIdentifier == "com.brave.Browser" ||
            bundleIdentifier == "com.microsoft.Edge" ||
            bundleIdentifier == "com.microsoft.edgemac" ||
            bundleIdentifier.hasPrefix("com.microsoft.Edge")
    }

    private func logPermissionState() {
        if !AXIsProcessTrusted() {
            AppLog.app.warning("Accessibility permission is not granted. Caret positioning may fall back to mouse location.")
        }

        if !CGPreflightListenEventAccess() {
            AppLog.app.warning("Input Monitoring permission is not granted. Event tap cannot receive keyboard events.")
        }
    }

    private func requestRequiredPermissionsIfNeeded() {
        requestAccessibilityPermissionIfNeeded()
        requestInputMonitoringPermissionIfNeeded()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        AXIsProcessTrustedWithOptions(options)
    }

    private func requestInputMonitoringPermissionIfNeeded() {
        guard !CGPreflightListenEventAccess() else { return }
        CGRequestListenEventAccess()
    }

    private func updatePermissionStatus() {
        statusItemController.updatePermissions(
            accessibility: AXIsProcessTrusted(),
            inputMonitoring: CGPreflightListenEventAccess()
        )
    }

    private static func openPrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]

        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }
            NSWorkspace.shared.open(url)
        }
    }
}
