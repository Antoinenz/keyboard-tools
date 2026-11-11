import Foundation

/// Holds the text to be typed and a cursor. No platform APIs, so it can be unit tested
/// and its behaviour re-implemented on other platforms.
struct TextFeeder {
    private(set) var characters: [Character] = []
    private(set) var index: Int = 0

    var total: Int { characters.count }
    var isFinished: Bool { index >= characters.count }
    var peek: Character? { isFinished ? nil : characters[index] }

    /// Replaces the text, keeping the cursor where it was (clamped to the new length).
    mutating func setText(_ text: String) {
        characters = Array(text)
        index = min(index, characters.count)
    }

    mutating func next() -> Character? {
        guard let c = peek else { return nil }
        index += 1
        return c
    }

    /// Like `next()`, but wraps back to the start after the last character.
    mutating func nextLooping() -> Character? {
        guard let c = next() else { return nil }
        if isFinished { index = 0 }
        return c
    }

    mutating func back() {
        index = max(0, index - 1)
    }

    mutating func reset() { index = 0 }

    /// Short preview of what is coming next, for the UI.
    func upcoming(_ count: Int = 24) -> String {
        guard !isFinished else { return "" }
        let end = min(characters.count, index + count)
        return String(characters[index..<end])
    }
}
