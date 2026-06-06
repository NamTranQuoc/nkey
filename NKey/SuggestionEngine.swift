import AppKit
import Foundation

final class SuggestionEngine {
    private enum SuggestionKind {
        case prefixCompletion
        case nextWordPrediction
    }

    private let spellChecker: NSSpellChecker
    private let nextWordPredictor: NextWordPredictor
    private var wordBuffer = ""
    private var lastCompletedWord = ""
    private var activeSuggestionKind: SuggestionKind?

    init(spellChecker: NSSpellChecker = .shared, nextWordPredictor: NextWordPredictor = NextWordPredictor()) {
        self.spellChecker = spellChecker
        self.nextWordPredictor = nextWordPredictor
    }

    var currentPrefixLength: Int {
        activeSuggestionKind == .prefixCompletion ? wordBuffer.count : 0
    }

    func reset() {
        wordBuffer.removeAll(keepingCapacity: true)
        lastCompletedWord.removeAll(keepingCapacity: true)
        activeSuggestionKind = nil
    }

    func suggestions(forTestingPrefix prefix: String) -> [String] {
        wordBuffer = prefix
        activeSuggestionKind = .prefixCompletion
        defer { reset() }
        return completions()
    }

    func processKeyDown(keyCode: CGKeyCode, characters: String) -> [String] {
        if keyCode == KeyCode.delete {
            return processDelete()
        }

        if keyCode == KeyCode.space {
            return processSpace()
        }

        if isBoundaryKey(keyCode) || isBoundaryText(characters) {
            reset()
            return []
        }

        guard characters.count == 1, isWordText(characters) else {
            return completions()
        }

        activeSuggestionKind = .prefixCompletion
        lastCompletedWord.removeAll(keepingCapacity: true)
        wordBuffer.append(characters)
        return completions()
    }

    func nextWordSuggestions(afterCommittedWord word: String) -> [String] {
        lastCompletedWord = word
        wordBuffer.removeAll(keepingCapacity: true)

        let predictions = nextWordPredictor.suggestions(after: lastCompletedWord)
        activeSuggestionKind = predictions.isEmpty ? nil : .nextWordPrediction
        return predictions
    }

    private func processDelete() -> [String] {
        if activeSuggestionKind == .nextWordPrediction, !lastCompletedWord.isEmpty {
            wordBuffer = lastCompletedWord
            lastCompletedWord.removeAll(keepingCapacity: true)
            activeSuggestionKind = .prefixCompletion
            return completions()
        }

        guard !wordBuffer.isEmpty else {
            reset()
            return []
        }

        activeSuggestionKind = .prefixCompletion
        wordBuffer.removeLast()
        return completions()
    }

    private func processSpace() -> [String] {
        guard !wordBuffer.isEmpty else {
            reset()
            return []
        }

        lastCompletedWord = wordBuffer
        wordBuffer.removeAll(keepingCapacity: true)

        return nextWordSuggestions(afterCommittedWord: lastCompletedWord)
    }

    private func completions() -> [String] {
        let prefix = wordBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.count >= 2 else {
            activeSuggestionKind = nil
            return []
        }

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

        let suggestions = Array(rankedCompletions.prefix(3))
        activeSuggestionKind = suggestions.isEmpty ? nil : .prefixCompletion
        return suggestions
    }

    private func isBoundaryKey(_ keyCode: CGKeyCode) -> Bool {
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
