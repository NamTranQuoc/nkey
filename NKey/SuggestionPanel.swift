import AppKit

final class SuggestionPanel: NSPanel {
    private enum Layout {
        static let optionWidth: CGFloat = 104
        static let height: CGFloat = 38
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 6
    }

    private let labels = (0..<3).map { _ in NSTextField(labelWithString: "") }
    private var suggestions: [String] = []
    private(set) var selectedIndex = 0

    var selectedSuggestion: String? {
        guard suggestions.indices.contains(selectedIndex) else { return nil }
        return suggestions[selectedIndex]
    }

    init() {
        let width = Layout.optionWidth * 3 + Layout.horizontalPadding * 2
        let frame = NSRect(x: 0, y: 0, width: width, height: Layout.height)

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        setupContent(width: width)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(suggestions: [String], near point: CGPoint) {
        guard !suggestions.isEmpty else {
            hide()
            return
        }

        self.suggestions = Array(suggestions.prefix(3))
        selectedIndex = 0
        updateLabels()
        updateFrame(near: point)
        orderFrontRegardless()
    }

    func hide() {
        suggestions.removeAll(keepingCapacity: true)
        selectedIndex = 0
        orderOut(nil)
    }

    func selectNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, suggestions.count - 1)
        updateLabels()
    }

    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
        updateLabels()
    }

    private func setupContent(width: CGFloat) {
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: Layout.height))
        container.material = .hudWindow
        container.blendingMode = .behindWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        container.layer?.masksToBounds = true

        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        for label in labels {
            label.alignment = .center
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.wantsLayer = true
            label.layer?.cornerRadius = 7
            label.layer?.masksToBounds = true
            stackView.addArrangedSubview(label)
            label.widthAnchor.constraint(equalToConstant: Layout.optionWidth).isActive = true
        }

        container.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Layout.horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -Layout.horizontalPadding),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: Layout.verticalPadding),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Layout.verticalPadding)
        ])

        contentView = container
    }

    private func updateFrame(near point: CGPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(point) }) ?? NSScreen.main else {
            setFrameOrigin(point)
            return
        }

        var origin = CGPoint(x: point.x, y: point.y - frame.height)
        let maxX = screen.visibleFrame.maxX - frame.width - 8
        let minX = screen.visibleFrame.minX + 8
        origin.x = min(max(origin.x, minX), maxX)
        origin.y = max(origin.y, screen.visibleFrame.minY + 8)
        setFrameOrigin(origin)
    }

    private func updateLabels() {
        for (index, label) in labels.enumerated() {
            let suggestion = suggestions.indices.contains(index) ? suggestions[index] : ""
            label.stringValue = suggestion
            label.isHidden = suggestion.isEmpty

            if index == selectedIndex {
                label.textColor = .controlAccentColor
                label.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            } else {
                label.textColor = .labelColor
                label.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
}
