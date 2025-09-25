//
//  MuhaffezViewModel+TwoPages.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/23/25.
//

import SwiftUI

extension MuhaffezViewModel {

    func updatePages() {
        guard pageMatchedWordsIndex < matchedWords.count else {
            return
        }
        tempPage.text = AttributedString()
        var currentLineIndex = pageCurrentLineIndex
        var wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
        var wordIndexInLine = 0
        let matchedWordsIndex = pageMatchedWordsIndex

        func advanceLine() {
            if quranModel.isRightPage(forAyahIndex: currentLineIndex) {
                rightPage = tempPage
            } else {
                leftPage = tempPage
            }
            currentLineIndex += 1
            wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
            wordIndexInLine = 0
        }

        func add(separator: AttributedString) {
            tempPage.text += separator
        }

        quranModel.updatePages(viewModel: self, ayahIndex: currentLineIndex)
        for i in (matchedWordsIndex..<matchedWords.count) {
            if currentPageIsRight != quranModel.isRightPage(forAyahIndex: currentLineIndex) {
                pageCurrentLineIndex = currentLineIndex
                pageMatchedWordsIndex = i
                tempPage.reset()
            }
            quranModel.updatePageModelsIfNeeded(viewModel: self, ayahIndex: currentLineIndex)
            if isBeginningOfAya(wordIndexInLine) {
                if quranModel.isEndOfSurah(currentLineIndex - 1) {
                    add(separator: surahSeparator(ayaIndex: currentLineIndex))
                }
                if quranModel.isEndOfRub3(currentLineIndex - 1) {
                    add(separator: AttributedString("⭐ "))
                }
            }
            let attributedWord = attributedWord(for: matchedWords[i].word, matched: matchedWords[i].isMatched)
            tempPage.text += attributedWord
            wordIndexInLine += 1
            add(separator: " ")
            if isEndOfAya(wordIndexInLine, wordsInCurrentLine.count) {
                add(separator: AttributedString("🌼 "))
                if quranModel.isEndOfSurah(currentLineIndex) {
                    add(separator: "\n")
                }
                advanceLine()
            }
        }
        if quranModel.isRightPage(forAyahIndex: currentLineIndex) {
            rightPage = tempPage
        } else {
            leftPage = tempPage
        }
    }

    // MARK: - Helpers

    private func attributedWord(for word: String, matched: Bool) -> AttributedString {
        var attributedWord = AttributedString(word)
        attributedWord.foregroundColor = matched ? .primary : .red
        attributedWord.font = .custom("KFGQPC Uthmanic Script", size: 30)
        return attributedWord
    }

    private func wordsForLine(_ lines: [String], at index: Int) -> [String] {
        guard index < lines.count else { return [] }
        return lines[index].split(separator: " ").map(String.init)
    }

    private func isBeginningOfAya(_ wordIndex: Int) -> Bool {
        return wordIndex == 0
    }

    private func isEndOfAya(_ wordIndex: Int, _ wordCount: Int) -> Bool {
        return wordIndex >= wordCount
    }

    private func surahSeparator(ayaIndex: Int) -> AttributedString {
        let surahName = quranModel.surahNameFor(ayahIndex: ayaIndex)
        let separator = AttributedString("\n\t\t\t\t\t")
        var name = AttributedString("سورة \(surahName)")
        name.font = .custom("KFGQPC Uthmanic Script", size: 30)
        name.underlineStyle = Text.LineStyle.single
        let separator2 = AttributedString("\n\n")
        return separator + name + separator2
    }
}

