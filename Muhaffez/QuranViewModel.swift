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
    @Published var matchedText: String = ""
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
    }

    // Map recognized words to closest Qur’an words
    private func matchedWords(from recognized: String) -> String {
        let quranWords = matchedAya.split(separator: " ").map { String($0) }
        let recognizedWords = recognized.split(separator: " ").map { String($0) }

        var results: [String] = []

        for recWord in recognizedWords {
            let normRec = recWord.normalizedArabic
            var bestMatch = recWord
            var bestScore = 0.0

            for qWord in quranWords {
                let score = normRec.similarity(to: qWord.normalizedArabic)
                if score > bestScore {
                    bestScore = score
                    bestMatch = qWord
                }
            }

            if bestScore >= 0.7 { // threshold
                results.append(bestMatch)
            }
        }

        return results.joined(separator: " ")
    }

    func speakArabic(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA")
        synthesizer.speak(utterance)
    }
}
