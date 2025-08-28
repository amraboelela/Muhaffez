//
//  MuhaffezViewModel+TwoPages.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/23/25.
//

import SwiftUI

extension MuhaffezViewModel {

  func updatePages() {
    tempRightPage.text = AttributedString()
    tempLeftPage.text = AttributedString()

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
        tempRightPage.text += separator
      } else {
        tempLeftPage.text += separator
      }
    }

    quranModel.updatePages(viewModel: self, ayahIndex: currentLineIndex)
    for (_, (word, isMatched)) in matchedWords.enumerated() {
      quranModel.updatePageModelsIfNeeded(viewModel: self, ayahIndex: currentLineIndex)
      if isBeginningOfAya(wordIndexInLine) {
        if quranModel.isEndOfSurah(currentLineIndex - 1) {
          add(separator: surahSeparator(ayaIndex: currentLineIndex))
          if quranModel.isEndOfRub3(currentLineIndex - 1) {
            add(separator: AttributedString("⭐ "))
          }
        }
      }
      let attributedWord = attributedWord(for: word, matched: isMatched)
      if quranModel.isRightPage(forAyahIndex: currentLineIndex) {
        tempRightPage.text += attributedWord
      } else {
        tempLeftPage.text += attributedWord
      }
      wordIndexInLine += 1
      add(separator: " ")
      if isEndOfAya(wordIndexInLine, wordsInCurrentLine.count) {
        add(separator: AttributedString("🌼 "))
        if quranModel.isEndOfSurah(currentLineIndex) {
          add(separator: "\n")
        }
        if quranModel.isEndOfRub3(currentLineIndex) && !quranModel.isEndOfSurah(currentLineIndex) {
          add(separator: AttributedString("⭐ "))
        }
        advanceLine()
      }
    }
    rightPage = tempRightPage
    leftPage = tempLeftPage
  }

  // MARK: - Helpers

  private func attributedWord(for word: String, matched: Bool) -> AttributedString {
    var attributedWord = AttributedString(word)
    attributedWord.foregroundColor = matched ? .primary : .red
    attributedWord.font = .custom("KFGQPC Uthmanic Script", size: 28)
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
    let surahName = QuranModel.shared.surahName(forAyahIndex: ayaIndex)
    let separator = AttributedString("\n\t\t\t\t")
    var name = AttributedString("سورة \(surahName)")
    name.font = .custom("KFGQPC Uthmanic Script", size: 28)
    name.underlineStyle = Text.LineStyle.single
    let separator2 = AttributedString("\n\n")
    return separator + name + separator2
  }
}

