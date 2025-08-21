//
//  ContentView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import Speech
import AVFoundation
import SwiftUI

@MainActor
class QuranViewModel: ObservableObject {

    var voiceText = "" {
        didSet {
            quranWords = quranText.split(separator: " ").map { String($0) }
            voiceWords = voiceText.split(separator: " ").map { String($0) }
            if !voiceText.isEmpty {
                updateFoundAyat()
                updateMatchedWords()
            }
        }
    }
    @Published var isRecording = false
    @Published var matchedWords: [(String, Bool)] = []
    private let synthesizer = AVSpeechSynthesizer()
    private var debounceTimer: Timer?
    private var peekTimer: Timer?
    let matchThreshold = 0.4

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
    var foundAyat = [Int]()
    var quranText = "" {
        didSet {
            quranWords = quranText.split(separator: " ").map { String($0) }
        }
    }
    var quranWords = [String]()
    var voiceWords = [String]()

    var displayText: AttributedString {
        guard let ayaIndex = foundAyat.first else {
            return AttributedString("")
        }
        return AttributedString.coloredFromMatched(matches: matchedWords, quranLines: quranLines, firstIndex: ayaIndex)
    }

    func resetData() {
        foundAyat.removeAll()
        quranText = ""
        matchedWords = []
        voiceText = ""
    }

    func updateFoundAyat() {
        guard !voiceText.isEmpty else {
            return
        }
        guard foundAyat.count != 1 else {
            return
        }
        foundAyat.removeAll()
        let normVoice = voiceText.normalizedArabic
        for (index, line) in quranLines.enumerated() {
            if line.normalizedArabic.hasPrefix(normVoice) {
                foundAyat.append(index)
            }
        }
        // If no prefix matches → debounce the expensive fallback
        if foundAyat.isEmpty {
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.performFallbackMatch(normVoice: normVoice)
                }
            }
        }
        print("#quran foundAyat: \(foundAyat)")
        updateQuranText()
    }

    private func performFallbackMatch(normVoice: String) {
        var bestIndex: Int?
        var bestScore = 0.0

        print("#quran performFallbackMatch normVoice: \(normVoice)")
        for (index, line) in quranLines.enumerated() {
            let lineNorm = line.normalizedArabic
            // Take only the prefix of the line equal to the length of normVoice
            if lineNorm.count < normVoice.count {
                continue
            }
            let prefix = String(lineNorm.prefix(normVoice.count))
            let score = normVoice.similarity(to: prefix)

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
            if score > 0.8 {
                break
            }
        }

        if let bestIndex {
            foundAyat = [bestIndex]
            print("#quran performFallbackMatch foundAyat: \(foundAyat)")
            updateQuranText()
            updateMatchedWords()
        }
    }

    func updateQuranText() {
        if let firstIndex = foundAyat.first {
            quranText = quranLines[firstIndex]
            print("#quran quranText: \(quranText)")
            if foundAyat.count == 1 {
                let endIndex = min(firstIndex + 100, quranLines.count)
                let extraLines = quranLines[(firstIndex + 1)..<endIndex]
                quranText = ([quranText] + extraLines).joined(separator: " ")
            }
        }
    }

    // Map voice words to closest Qur’an words
    func updateMatchedWords() {
        guard foundAyat.count == 1 else {
            return
        }
        peekTimer?.invalidate()
        peekTimer = nil
        peekTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.peekHelper()
            }
        }

        var results: [(String, Bool)] = []

        var quranWordsIndex = -1
        for voiceWord in voiceWords {
            quranWordsIndex += 1
            guard quranWordsIndex < quranWords.count else {
                break
            }
            let normVoiceWord = voiceWord.normalizedArabic
            var qWord = quranWords[quranWordsIndex]
            var normQWord = qWord.normalizedArabic
            var score = normVoiceWord.similarity(to: normQWord)
            if score >= matchThreshold {
                results.append((qWord, true))
            } else {
                if quranWordsIndex - 1 >= 0 { // check backward
                    qWord = quranWords[quranWordsIndex - 1]
                    normQWord = qWord.normalizedArabic
                    score = normVoiceWord.similarity(to: normQWord)
                    if score >= matchThreshold {
                        quranWordsIndex -= 1
                        results.removeLast()
                        results.append((qWord, true))
                        continue
                    } else if quranWordsIndex - 2 >= 0 {
                        qWord = quranWords[quranWordsIndex - 2]
                        normQWord = qWord.normalizedArabic
                        score = normVoiceWord.similarity(to: normQWord)
                        if score >= matchThreshold {
                            quranWordsIndex -= 2
                            results.removeLast(2)
                            results.append((qWord, true))
                            continue
                        } else if quranWordsIndex - 3 >= 0 {
                            qWord = quranWords[quranWordsIndex - 3]
                            normQWord = qWord.normalizedArabic
                            score = normVoiceWord.similarity(to: normQWord)
                            if score >= matchThreshold {
                                quranWordsIndex -= 3
                                results.removeLast(3)
                                results.append((qWord, true))
                                continue
                            }
                        }
                    }
                }
                if quranWordsIndex + 1 < quranWords.count { // check forward
                    qWord = quranWords[quranWordsIndex + 1]
                    normQWord = qWord.normalizedArabic
                    score = normVoiceWord.similarity(to: normQWord)
                    if score >= matchThreshold {
                        results.append((quranWords[quranWordsIndex], false))
                        quranWordsIndex += 1
                        results.append((quranWords[quranWordsIndex], true))
                        continue
                    } else if quranWordsIndex + 2 < quranWords.count {
                        qWord = quranWords[quranWordsIndex + 2]
                        normQWord = qWord.normalizedArabic
                        score = normVoiceWord.similarity(to: normQWord)
                        if score >= matchThreshold {
                            results.append((quranWords[quranWordsIndex], false))
                            quranWordsIndex += 1
                            results.append((quranWords[quranWordsIndex], false))
                            quranWordsIndex += 1
                            results.append((quranWords[quranWordsIndex], true))
                            continue
                        } else if quranWordsIndex + 3 < quranWords.count {
                            qWord = quranWords[quranWordsIndex + 3]
                            normQWord = qWord.normalizedArabic
                            score = normVoiceWord.similarity(to: normQWord)
                            if score >= matchThreshold {
                                results.append((quranWords[quranWordsIndex], false))
                                quranWordsIndex += 1
                                results.append((quranWords[quranWordsIndex], false))
                                quranWordsIndex += 1
                                results.append((quranWords[quranWordsIndex], false))
                                quranWordsIndex += 1
                                results.append((quranWords[quranWordsIndex], true))
                                continue
                            }
                        }
                    }
                }
                results.append((quranWords[quranWordsIndex], false))
            }
        }
        matchedWords = results
        print("#quran matchedWords: \(matchedWords)")
    }

    func peekHelper() {
        print("#quran peekHelper")
        guard isRecording else {
            return
        }
        var results = matchedWords
        var quranWordsIndex = matchedWords.count
        if quranWordsIndex + 2 < quranWords.count {
            var voiceToSpeak = quranWords[quranWordsIndex] + " "
            results.append((quranWords[quranWordsIndex], false))
            quranWordsIndex += 1
            voiceToSpeak += quranWords[quranWordsIndex]
            results.append((quranWords[quranWordsIndex], false))
            matchedWords = results
            print("#quran matchedWords: \(matchedWords)")
        }
    }
}
