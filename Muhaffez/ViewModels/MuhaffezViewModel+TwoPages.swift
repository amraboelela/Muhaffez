//
//  MuhaffezViewModel+TwoPages.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/23/25.
//

import SwiftUI

extension MuhaffezViewModel {

    func updatePages() {
        print("updatePages()")
        guard pageMatchedWordsIndex < matchedWords.count else {
            print("pageMatchedWordsIndex < matchedWords.count, pageMatchedWordsIndex: \(pageMatchedWordsIndex), matchedWords.count: \(matchedWords.count)")
            return
        }
        tempPage.text = AttributedString()
        var currentLineIndex = pageCurrentLineIndex
        var wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
        var wordIndexInLine = 0
        let matchedWordsIndex = pageMatchedWordsIndex

        func advanceLine() {
            if quranModel.isRightPage(forAyahIndex: currentLineIndex) {
                tempPage.pageType = .right
                rightPage = tempPage
            } else {
                tempPage.pageType = .left
                leftPage = tempPage
            }
            currentLineIndex += 1
            wordsInCurrentLine = wordsForLine(quranLines, at: currentLineIndex)
            wordIndexInLine = 0
        }

        func add(separator: AttributedString) {
            tempPage.text += separator
        }

        applyPageInfo(for: currentLineIndex)
        for i in (matchedWordsIndex..<matchedWords.count) {
            if currentPageIsRight != quranModel.isRightPage(forAyahIndex: currentLineIndex) {
                pageCurrentLineIndex = currentLineIndex
                pageMatchedWordsIndex = i
                tempPage.reset()
            }
            updatePageIfPageChanged(for: currentLineIndex)
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
            print("updatePages, quranModel.isRightPage")
            if !tempPage.isEmpty {
                tempPage.pageType = .right
                rightPage = tempPage
            }
        } else {
            print("updatePages, !quranModel.isRightPage")
            if !tempPage.isEmpty {
                tempPage.pageType = .left
                leftPage = tempPage
            }
        }
    }

    // MARK: - Page Info Helpers

    private func applyPageInfo(for index: Int) {
        tempPage.juzNumber = quranModel.juzNumberFor(ayahIndex: index)
        tempPage.surahName = quranModel.surahNameFor(ayahIndex: index)
        tempPage.pageNumber = quranModel.pageNumber(forAyahIndex: index)
        currentPageIsRight = quranModel.isRightPage(forAyahIndex: index)
    }

    private func updatePageIfPageChanged(for index: Int) {
        guard currentPageIsRight != quranModel.isRightPage(forAyahIndex: index) else { return }
        applyPageInfo(for: index)
        if currentPageIsRight {
            leftPage.pageType = .preLeft
        }
    }

    // MARK: - Helpers

    private func attributedWord(for word: String, matched: Bool) -> AttributedString {
        var attributedWord = AttributedString(word)
        attributedWord.foregroundColor = matched ? .primary : .red
        attributedWord.font = .custom("Traditional Arabic", size: 28)
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
        name.font = .custom("Traditional Arabic", size: 30)
        name.underlineStyle = Text.LineStyle.single
        let separator2 = AttributedString("\n\n")
        return separator + name + separator2
    }
}

