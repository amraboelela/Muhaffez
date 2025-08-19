//
//  String.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import Foundation

import Foundation

extension String {
    /// Remove all Arabic diacritics (tashkeel)
    var removingTashkeel: String {
        self.applyingTransform(.stripDiacritics, reverse: false) ?? self
    }

    var normalizedArabic: String {
        // 1. Remove diacritics (tashkeel)
        var text = self.removingTashkeel

        // 2. Normalize hamza variants
        let hamzaMap: [Character: Character] = [
            "إ": "ا", "أ": "ا", "آ": "ا",
            "ؤ": "و", "ئ": "ي" // optionally normalize these too
        ]

        text = String(text.map { hamzaMap[$0] ?? $0 })
        return text
    }

    func findIn(lines: [String]) -> String? {
        let normalizedSearch = self.normalizedArabic
        return lines.first { line in
            let normalizedLine = line.normalizedArabic
            //print("normalizedLine: \(normalizedLine)")
            return normalizedLine.contains(normalizedSearch)
        }
    }

    func findLineStartingIn(lines: [String]) -> (line: String, index: Int)? {
        let normalizedSearch = self.normalizedArabic

        for (i, line) in lines.enumerated() {
            if line.normalizedArabic.hasPrefix(normalizedSearch) {
                return (line, i)
            }
        }
        return nil
    }
}
