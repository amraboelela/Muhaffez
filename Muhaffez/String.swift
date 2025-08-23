//
//  String.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import Foundation

extension String {
    /// Remove all Arabic diacritics (tashkeel)
    var removingTashkeel: String {
        String(self.unicodeScalars.filter {
            !CharacterSet.arabicDiacritics.contains($0)
        })
    }

    func removingControlCharacters() -> String {
        self.replacingOccurrences(of: "\\p{Cf}", with: "", options: .regularExpression)
    }

    var normalizedArabic: String {
        // 1. Remove diacritics (tashkeel) and control characters
        var text = self.removingTashkeel.removingControlCharacters()

        // 2. Normalize hamza variants
        let hamzaMap: [Character: Character] = [
            "إ": "ا", "أ": "ا", "آ": "ا",
            "ؤ": "و", "ئ": "ي"
        ]
        text = String(text.map { hamzaMap[$0] ?? $0 })

        let a3ozo = "اعوذ بالله من الشيطان الرجيم"
        if text.hasPrefix(a3ozo) {
            text.removeSubrange(text.startIndex..<text.index(text.startIndex, offsetBy: a3ozo.count))
            text = text.trimmingCharacters(in: .whitespaces)
        }
        // 3. Remove "بسم الله الرحمن الرحيم" at the beginning if present
        let basmala = "بسم الله الرحمن الرحيم"
        if text.hasPrefix(basmala) {
            text.removeSubrange(text.startIndex..<text.index(text.startIndex, offsetBy: basmala.count))
            text = text.trimmingCharacters(in: .whitespaces)
        }

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

    // Levenshtein distance
    func levenshteinDistance(to target: String) -> Int {
        let sourceArray = Array(self)
        let targetArray = Array(target)
        let (n, m) = (sourceArray.count, targetArray.count)
        var dist = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        for i in 0...n { dist[i][0] = i }
        for j in 0...m { dist[0][j] = j }

        for i in 1...n {
            for j in 1...m {
                if sourceArray[i - 1] == targetArray[j - 1] {
                    dist[i][j] = dist[i - 1][j - 1]
                } else {
                    dist[i][j] = Swift.min(
                        dist[i - 1][j] + 1,
                        dist[i][j - 1] + 1,
                        dist[i - 1][j - 1] + 1
                    )
                }
            }
        }
        return dist[n][m]
    }

    // Similarity ratio (0...1)
    func similarity(to other: String) -> Double {
        let maxLen = max(self.count, other.count)
        if maxLen == 0 { return 1.0 }
        let dist = self.levenshteinDistance(to: other)
        return 1.0 - Double(dist) / Double(maxLen)
    }
}
