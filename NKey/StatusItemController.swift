import AppKit

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let eventTapItem = NSMenuItem(title: "Event Tap: Unknown", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(title: "Accessibility: Unknown", action: nil, keyEquivalent: "")
    private let inputMonitoringItem = NSMenuItem(title: "Input Monitoring: Unknown", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "Toggle Mode", action: #selector(toggleMode), keyEquivalent: "")
    private let suggestionListItem = NSMenuItem(title: "Suggestion List", action: #selector(toggleSuggestionList), keyEquivalent: "")
    private let restartEventTapItem = NSMenuItem(title: "Restart", action: #selector(restartEventTap), keyEquivalent: "")
    private let privacySettingsItem = NSMenuItem(title: "Open Privacy Settings", action: #selector(openPrivacySettings), keyEquivalent: "")
    private let quitItem = NSMenuItem(title: "Quit NKey", action: #selector(quit), keyEquivalent: "q")

    var onToggle: (() -> Void)?
    var onToggleSuggestionList: (() -> Void)?
    var onRestartEventTap: (() -> Void)?
    var onOpenPrivacySettings: (() -> Void)?
    var onQuit: (() -> Void)?

    override init() {
        super.init()
        setupMenu()
    }

    func update(mode: InputMode) {
        statusItem.button?.title = mode.statusTitle
        toggleItem.title = "Switch to \(mode == .english ? InputMode.vietnamese.statusTitle : InputMode.english.statusTitle)"
    }

    func updateEventTap(isRunning: Bool) {
        eventTapItem.title = "Event Tap: \(isRunning ? "On" : "Off")"
    }

    func updatePermissions(accessibility: Bool, inputMonitoring: Bool) {
        accessibilityItem.title = "Accessibility: \(accessibility ? "On" : "Off")"
        inputMonitoringItem.title = "Input Monitoring: \(inputMonitoring ? "On" : "Off")"
    }

    func updateSuggestionList(isEnabled: Bool) {
        suggestionListItem.state = isEnabled ? .on : .off
    }

    private func setupMenu() {
        statusItem.button?.title = InputMode.english.statusTitle
        eventTapItem.isEnabled = false
        accessibilityItem.isEnabled = false
        inputMonitoringItem.isEnabled = false

        let menu = NSMenu()
        toggleItem.target = self
        suggestionListItem.target = self
        restartEventTapItem.target = self
        privacySettingsItem.target = self
        quitItem.target = self
        menu.addItem(eventTapItem)
        menu.addItem(accessibilityItem)
        menu.addItem(inputMonitoringItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(suggestionListItem)
        menu.addItem(privacySettingsItem)
        menu.addItem(.separator())
        menu.addItem(restartEventTapItem)
        menu.addItem(quitItem)
        statusItem.menu = menu
        update(mode: .english)
        updateSuggestionList(isEnabled: true)
        updateEventTap(isRunning: false)
        updatePermissions(accessibility: false, inputMonitoring: false)
    }

    @objc private func toggleMode() {
        onToggle?()
    }

    @objc private func toggleSuggestionList() {
        onToggleSuggestionList?()
    }

    @objc private func restartEventTap() {
        onRestartEventTap?()
    }

    @objc private func openPrivacySettings() {
        onOpenPrivacySettings?()
    }

    @objc private func quit() {
        onQuit?()
    }
}
