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
    var voiceText: String = "" {
        didSet {
            updateMatchedWords()
        }
    }
    @Published var matchedWords: [(String, Bool)] = []
    private let synthesizer = AVSpeechSynthesizer()
    let matchThreshold = 0.7

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
    var quranText = """
    إِنَّ اللَّهَ يَأمُرُكُم أَن تُؤَدُّوا الأَماناتِ إِلىٰ أَهلِها وَإِذا حَكَمتُم بَينَ النّاسِ أَن تَحكُموا بِالعَدلِ إِنَّ اللَّهَ نِعِمّا يَعِظُكُم بِهِ إِنَّ اللَّهَ كانَ
    """

    // Map voice words to closest Qur’an words
    func updateMatchedWords() {
        let quranWords = quranText.split(separator: " ").map { String($0) }
        let voiceWords = voiceText.split(separator: " ").map { String($0) }

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
                            }
                        } else {
                            results.append((quranWords[quranWordsIndex], false))
                        }
                    }
                }
            }
        }

        matchedWords = results
        print("#quran matchedWords: \(matchedWords)")
    }

    func speakArabic(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA")
        synthesizer.speak(utterance)
    }
}
