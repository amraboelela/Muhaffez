//
//  ContentView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import Speech
import AVFoundation

@MainActor
class QuranViewModel: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var matchedText: [(String, Bool)] = []
    private let synthesizer = AVSpeechSynthesizer()

    // Load file into memory at app launch
    let quranLines: [String] = {
        if let path = Bundle.main.path(forResource: "quran-simple-min", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                // Split into lines
                return content.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty } // remove empty lines
            } catch {
                print("❌ Error reading file:", error)
                return []
            }
        } else {
            print("❌ File not found in bundle")
            return []
        }
    }()
    var matchedAya = """
    إِنَّ اللَّهَ يَأمُرُكُم أَن تُؤَدُّوا الأَماناتِ إِلىٰ أَهلِها وَإِذا حَكَمتُم بَينَ النّاسِ أَن تَحكُموا بِالعَدلِ إِنَّ اللَّهَ نِعِمّا يَعِظُكُم بِهِ إِنَّ اللَّهَ كانَ
    """

    func updateRecognizedText(_ newText: String) {
        recognizedText = newText
        matchedText = matchedWords(from: newText)
        print("#quran matchedText: \(matchedText)")
    }

    // Map recognized words to closest Qur’an words
    func matchedWords(from recognized: String) -> [(String, Bool)] {
        let quranWords = matchedAya.split(separator: " ").map { String($0) }
        let recognizedWords = recognized.split(separator: " ").map { String($0) }

        var results: [(String, Bool)] = []

        for (i, recWord) in recognizedWords.enumerated() {
            let normRec = recWord.normalizedArabic
            var bestMatch = recWord
            var bestScore = 0.0

            // 1. Try position-based match if within range
            if i < quranWords.count {
                let qWord = quranWords[i]
                let score = normRec.similarity(to: qWord.normalizedArabic)
                if score >= 0.7 {
                    results.append((qWord, true))
                    continue
                } else {
                    // candidate but not confident
                    bestScore = score
                    bestMatch = qWord
                }
            }

            // 2. Global fallback search among all quranWords
            for qWord in quranWords {
                let score = normRec.similarity(to: qWord.normalizedArabic)
                if score > bestScore {
                    bestScore = score
                    bestMatch = qWord
                }
            }

            // always return something — mark true if above threshold, false otherwise
            results.append((bestMatch, bestScore >= 0.7))
        }

        return results
    }

    func speakArabic(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA")
        synthesizer.speak(utterance)
    }
}
