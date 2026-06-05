import AppKit
import Foundation

final class SuggestionEngine {
    private let spellChecker: NSSpellChecker
    private var wordBuffer = ""

    init(spellChecker: NSSpellChecker = .shared) {
        self.spellChecker = spellChecker
    }

    var currentPrefixLength: Int {
        wordBuffer.count
    }

    func reset() {
        wordBuffer.removeAll(keepingCapacity: true)
    }

    func suggestions(forTestingPrefix prefix: String) -> [String] {
        wordBuffer = prefix
        defer { reset() }
        return completions()
    }

    func processKeyDown(keyCode: CGKeyCode, characters: String) -> [String] {
        if keyCode == KeyCode.delete {
            if !wordBuffer.isEmpty {
                wordBuffer.removeLast()
            }
            return completions()
        }

        if isBoundaryKey(keyCode) || isBoundaryText(characters) {
            reset()
            return []
        }

        guard characters.count == 1, isWordText(characters) else {
            return completions()
        }

        wordBuffer.append(characters)
        return completions()
    }

    private func completions() -> [String] {
        let prefix = wordBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.count >= 2 else { return [] }

        let range = NSRange(location: 0, length: prefix.utf16.count)
        let rawCompletions = spellChecker.completions(
            forPartialWordRange: range,
            in: prefix,
            language: "en",
            inSpellDocumentWithTag: 0
        ) ?? []

        let lowercasedPrefix = prefix.lowercased()
        var seen = Set<String>()

        let rankedCompletions = rawCompletions
            .filter { completion in
                let normalized = completion.lowercased()
                return normalized.hasPrefix(lowercasedPrefix) && normalized != lowercasedPrefix
            }
            .filter { completion in
                seen.insert(completion.lowercased()).inserted
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }
                return lhs.count < rhs.count
            }

        return Array(rankedCompletions.prefix(3))
    }

    private func isBoundaryKey(_ keyCode: CGKeyCode) -> Bool {
        keyCode == KeyCode.space ||
            keyCode == KeyCode.return ||
            keyCode == KeyCode.tab ||
            keyCode == KeyCode.escape
    }

    private func isBoundaryText(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.unicodeScalars.contains { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar) ||
                CharacterSet.punctuationCharacters.contains(scalar) ||
                CharacterSet.symbols.contains(scalar)
        }
    }

    private func isWordText(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { scalar in
            CharacterSet.letters.contains(scalar) || scalar == "'"
        }
    }
}
