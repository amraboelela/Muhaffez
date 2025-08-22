//
//  AttributedString.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/19/25.
//

import SwiftUI

extension AttributedString {

    static func coloredFromMatched(
        matches: [(String, Bool)],
        quranLines: [String],
        firstIndex: Int
    ) -> AttributedString {
        var result = AttributedString()

        var currentLineIndex = firstIndex
        var wordsInCurrentLine = quranLines.isEmpty ? [] : quranLines[currentLineIndex].split(separator: " ").map(String.init)
        var wordCountInLine = wordsInCurrentLine.count
        var wordIndexInLine = 0

        for (index, (word, isMatched)) in matches.enumerated() {
            var attributedWord = AttributedString(word)
            attributedWord.foregroundColor = isMatched ? .darkGreen : .red
            attributedWord.font = .system(size: 18, weight: .regular)

            result += attributedWord
            wordIndexInLine += 1

            // Add space or star if we finish the ayah
            if wordIndexInLine >= wordCountInLine {
                result += " ⭐ "
                currentLineIndex += 1
                if currentLineIndex < quranLines.count {
                    wordsInCurrentLine = quranLines[currentLineIndex].split(separator: " ").map(String.init)
                    wordCountInLine = wordsInCurrentLine.count
                    wordIndexInLine = 0
                }
            } else if index < matches.count - 1 {
                result += " "
            }
        }

        return result
    }

}

