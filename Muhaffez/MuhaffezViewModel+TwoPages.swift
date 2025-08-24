//
//  MuhaffezViewModel+TwoPages.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/23/25.
//

import SwiftUI

extension MuhaffezViewModel {

    // MARK: - Computed Properties

    func updatePageTexts() {
        rightPageText = AttributedString()
        leftPageText = AttributedString()

        guard let firstIndex = foundAyat.first else { return }

        var currentLineIndex = firstIndex
        var wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
        var wordIndexInLine = 0

        func advanceLine() {
            currentLineIndex += 1
            wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
            wordIndexInLine = 0
        }

        for (index, (word, isMatched)) in matchedWords.enumerated() {
            let attributedWord = attributedWord(for: word, matched: isMatched)

            // Append directly to the correct page
            if QuranModel.shared.isRightPage(forAyahIndex: currentLineIndex) {
                rightPageText += attributedWord
            } else {
                leftPageText += attributedWord
            }

            wordIndexInLine += 1

            // Add separators if needed
            if isEndOfSurah(currentLineIndex) {
                let separator = addSurahSeparator(ayaIndex: currentLineIndex + 1)
                if QuranModel.shared.isRightPage(forAyahIndex: currentLineIndex) {
                    rightPageText += separator
                } else {
                    leftPageText += separator
                }
                advanceLine()
            } else if isEndOfRub3(currentLineIndex) {
                let separator = addRub3Separator()
                if QuranModel.shared.isRightPage(forAyahIndex: currentLineIndex) {
                    rightPageText += separator
                } else {
                    leftPageText += separator
                }
                advanceLine()
            } else if isEndOfAya(wordIndexInLine, wordsInCurrentLine.count) {
                let separator = addAyahSeparator()
                if QuranModel.shared.isRightPage(forAyahIndex: currentLineIndex) {
                    rightPageText += separator
                } else {
                    leftPageText += separator
                }
                advanceLine()
            } else if index < matchedWords.count - 1 {
                let space = addSpace()
                if QuranModel.shared.isRightPage(forAyahIndex: currentLineIndex) {
                    rightPageText += space
                } else {
                    leftPageText += space
                }
            }
        }
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

    private func isEndOfSurah(_ ayahIndex: Int) -> Bool {
        return surahMarkers.contains(ayahIndex + 1) // markers are 1-based usually
    }

    private func addAyahSeparator() -> AttributedString {
        return AttributedString(" 🌼 ")
    }

    private func addRub3Separator() -> AttributedString {
        return AttributedString(" ⭐ ")
    }

    private func addSurahSeparator(ayaIndex: Int) -> AttributedString {
        return AttributedString("\n\n────────── \(QuranModel.shared.surahName(forAyahIndex: ayaIndex))  ──────────\n\n")
    }

    private func addSpace() -> AttributedString {
        return AttributedString(" ")
    }
}

