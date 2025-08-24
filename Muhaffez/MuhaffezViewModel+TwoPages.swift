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

        let quranModel = QuranModel.shared
        var currentLineIndex = firstIndex
        var wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
        var wordIndexInLine = 0

        func advanceLine() {
            currentLineIndex += 1
            wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
            wordIndexInLine = 0
        }

        func add(separator: AttributedString) {
            if quranModel.isRightPage(forAyahIndex: currentLineIndex) {
                rightPageText += separator
            } else {
                leftPageText += separator
            }
        }

        for (index, (word, isMatched)) in matchedWords.enumerated() {
            let attributedWord = attributedWord(for: word, matched: isMatched)

            // Append directly to the correct page
            if quranModel.isRightPage(forAyahIndex: currentLineIndex) {
                rightPageText += attributedWord
            } else {
                leftPageText += attributedWord
            }

            wordIndexInLine += 1
            if index < matchedWords.count - 1 {
                add(separator: " ")
            }
            var needToAdvanceLine = false
            if quranModel.isEndOfSurah(currentLineIndex) {
                add(separator: surahSeparator(ayaIndex: currentLineIndex + 1))
                needToAdvanceLine = true
            }
            if quranModel.isEndOfRub3(currentLineIndex) {
                add(separator: AttributedString("⭐ "))
                needToAdvanceLine = true
            } else if isEndOfAya(wordIndexInLine, wordsInCurrentLine.count) {
                add(separator: AttributedString("🌼 "))
                needToAdvanceLine = true
            }
            if needToAdvanceLine {
                advanceLine()
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

    private func surahSeparator(ayaIndex: Int) -> AttributedString {
        let surahName = QuranModel.shared.surahName(forAyahIndex: ayaIndex)
        let separator = AttributedString("\n──────────\n")
        var name = AttributedString("سورة \(surahName)")
        name.font = .system(size: 20, weight: .bold)
        let separator2 = AttributedString("\n──────────\n")
        return separator + name + separator2
    }
}

