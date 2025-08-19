//
//  AttributedString.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/19/25.
//

import SwiftUI

extension AttributedString {
    static func coloredFromMatched(_ matches: [(String, Bool)]) -> AttributedString {
        var result = AttributedString()

        for (index, (word, isMatched)) in matches.enumerated() {
            var attributedWord = AttributedString(word)

            // Apply attributes directly and in a type-safe way
            attributedWord.foregroundColor = isMatched ? .green : .red
            attributedWord.font = .system(size: 18, weight: .regular)

            // Append the word to the result
            result += attributedWord

            // Add space between words
            if index < matches.count - 1 {
                result += " "
            }
        }
        return result
    }
}

