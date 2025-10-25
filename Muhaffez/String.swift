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

        //        let a3ozo = "اعوذ بالله من الشيطان الرجيم"
        //        if text.hasPrefix(a3ozo) {
        //            text.removeSubrange(text.startIndex..<text.index(text.startIndex, offsetBy: a3ozo.count))
        //            text = text.trimmingCharacters(in: .whitespaces)
        //        }
        //        // 3. Remove "بسم الله الرحمن الرحيم" at the beginning if present
        //        let basmala = "بسم الله الرحمن الرحيم"
        //        if text.hasPrefix(basmala) {
        //            text.removeSubrange(text.startIndex..<text.index(text.startIndex, offsetBy: basmala.count))
        //            text = text.trimmingCharacters(in: .whitespaces)
        //        }

        return text
    }

    var removeBasmallah: String {
        // Expected Bismillah words: ["بسم", "الله", "الرحمن", "الرحيم"]
        let bismillahWords = ["بسم", "الله", "الرحمن", "الرحيم"]
        let normalizedText = self.normalizedArabic
        let words = normalizedText.split(separator: " ").map { String($0) }

        // Need at least 3 words to check for incomplete Bismillah
        guard words.count >= 3 else { return self }

        // Check if starts with "بسم الله"
        let similarityThreshold = 0.8
        if words[0].similarity(to: bismillahWords[0]) < similarityThreshold ||
           words[1].similarity(to: bismillahWords[1]) < similarityThreshold {
            return "" // Doesn't start with Bismillah at all
        }

        // Check if we have 4 words and they match full Bismillah
        if words.count >= 4 {
            let word2Matches = words[2].similarity(to: bismillahWords[2]) >= similarityThreshold
            let word3Matches = words[3].similarity(to: bismillahWords[3]) >= similarityThreshold

            if word2Matches && word3Matches {
                // Full Bismillah: drop first 4 words
                return words.dropFirst(4).joined(separator: " ")
            }
        }

        // Check for incomplete Bismillah (3 words)
        if words.count >= 3 {
            // Case 1: "بسم الله الرحمن" (missing "الرحيم")
            if words[2].similarity(to: bismillahWords[2]) >= similarityThreshold {
                return words.dropFirst(3).joined(separator: " ")
            }
            // Case 2: "بسم الله الرحيم" (missing "الرحمن")
            if words[2].similarity(to: bismillahWords[3]) >= similarityThreshold {
                return words.dropFirst(3).joined(separator: " ")
            }
        }

        // Doesn't match Bismillah pattern
        return ""
    }

    var removeA3ozoBellah: String {
        let words = self.split(separator: " ")
        guard words.count >= 5 else { return self }
        return words.dropFirst(5).joined(separator: " ")
    }

    var hasA3ozoBellah: Bool {
        // A3ozoBellah: "أعوذ بالله من الشيطان الرجيم"
        let a3ozoWords = ["اعوذ", "بالله", "من", "الشيطان", "الرجيم"]
        let normalizedText = self.normalizedArabic
        let words = normalizedText.split(separator: " ").map { String($0) }

        // Need at least 5 words to check
        guard words.count >= 5 else { return false }

        // Check similarity of first 5 words to a3ozo words
        let similarityThreshold = 0.8
        for i in 0..<4 {
            let similarity = words[i].similarity(to: a3ozoWords[i])
            if similarity < similarityThreshold {
                return false
            }
        }
        return true
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

        // Handle empty strings
        if n == 0 { return m }
        if m == 0 { return n }

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
