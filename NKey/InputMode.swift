import Foundation

enum InputMode: String {
    case english
    case vietnamese

    var statusTitle: String {
        switch self {
        case .english:
            return "EN"
        case .vietnamese:
            return "VI"
        }
    }
}

final class InputModeState {
    private(set) var current: InputMode = .english {
        didSet {
            guard oldValue != current else { return }
            onChange?(current)
        }
    }

    var onChange: ((InputMode) -> Void)?

    func toggle() {
        current = current == .english ? .vietnamese : .english
    }

    func set(_ mode: InputMode) {
        current = mode
    }
}
