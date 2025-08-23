//
//  MuhaffezViewModel+TwoPages.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/23/25.
//

import SwiftUI

extension MuhaffezViewModel {

    // MARK: - Computed Properties

    var displayText: AttributedString {
        guard let firstIndex = foundAyat.first else { return AttributedString("") }
        var result = AttributedString()
        var currentLineIndex = firstIndex
        var wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
        var wordCountInLine = wordsInCurrentLine.count
        var wordIndexInLine = 0
        for (index, (word, isMatched)) in matchedWords.enumerated() {
            result += attributedWord(for: word, matched: isMatched)
            wordIndexInLine += 1
            if isEndOfAya(wordIndexInLine, wordCountInLine) {
                result += addAyahSeparator()
                // If the ayah is at the end of a rub3, add rub3 separator
                if isEndOfRub3(currentLineIndex) {
                    result += addRub3Separator()
                }
                currentLineIndex += 1
                wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
                wordCountInLine = wordsInCurrentLine.count
                wordIndexInLine = 0
            } else if index < matchedWords.count - 1 {
                result += addSpace()
            }
        }
        return result
    }

    // MARK: - Helpers

    private func attributedWord(for word: String, matched: Bool) -> AttributedString {
        var attributedWord = AttributedString(word)
        attributedWord.foregroundColor = matched ? .darkGreen : .red
        attributedWord.font = .system(size: 18, weight: .regular)
        return attributedWord
    }

    private func wordsForLine(_ lines: [String], at index: Int) -> [String] {
        guard index < lines.count else { return [] }
        return lines[index].split(separator: " ").map(String.init)
    }

    private func isEndOfAya(_ wordIndex: Int, _ wordCount: Int) -> Bool {
        return wordIndex >= wordCount
    }

    /// Helper: true if current ayah index is at the end of a rub3
    private func isEndOfRub3(_ ayahIndex: Int) -> Bool {
        return rub3Markers.contains(ayahIndex + 1) // markers are 1-based usually
    }
    
    private func addAyahSeparator() -> AttributedString {
        return AttributedString(" 🌼 ")
    }

    private func addRub3Separator() -> AttributedString {
        return AttributedString(" ⭐ ")
    }

    private func addSpace() -> AttributedString {
        return AttributedString(" ")
    }
}

