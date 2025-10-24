//
//  MuhaffezViewModel.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import AVFoundation
import SwiftUI

@MainActor
@Observable
class MuhaffezViewModel {

    // MARK: - Public Properties

    var voiceText = "" {
        didSet {
            voiceWords = voiceText.normalizedArabic.split(separator: " ").map { String($0) }
            if !voiceText.isEmpty {
                if foundAyat.count != 1 {
                    updateFoundAyat()
                } else {
                    updateMatchedWords()
                }
            }
        }
    }
    var voiceTextHasBesmillah = false

    var isRecording = false
    var matchedWords: [(word: String, isMatched: Bool)] = [] {
        didSet {
            updatePages()
        }
    }
    var previousVoiceWordsCount = 0

    var foundAyat = [Int]() {
        didSet {
            pageCurrentLineIndex = foundAyat.first ?? 0
        }
    }

    var quranText = "" {
        didSet {
            quranWords = quranText.split(separator: " ").map { String($0) }
        }
    }

    var quranWords = [String]()
    var voiceWords = [String]()
    var tempPage = PageModel()
    var rightPage = PageModel()
    var leftPage = PageModel()
    var currentPageIsRight = true {
        didSet {
            if !oldValue && currentPageIsRight {
                rightPage.reset()
            }
        }
    }
    var pageCurrentLineIndex = 0
    var pageMatchedWordsIndex = 0

    let quranModel = QuranModel.shared
    let quranLines = QuranModel.shared.quranLines

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var debounceTimer: Timer?
    private var peekTimer: Timer?
    private let matchThreshold = 0.7
    private let simiMatchThreshold = 0.6
    private let seekMatchThreshold = 0.95
    private let mlModel = AyaFinderMLModel()

    // MARK: - Public Actions

    func resetData() {
        debounceTimer?.invalidate()
        foundAyat.removeAll()
        quranText = ""
        matchedWords = []
        voiceText = ""
        currentPageIsRight = true
        tempPage.reset()
        tempPage.isFirstPage = true
        rightPage.reset()
        leftPage.reset()
        pageCurrentLineIndex = 0
        pageMatchedWordsIndex = 0
        previousVoiceWordsCount = 0
        voiceTextHasBesmillah = false
    }

    // MARK: - Aya Matching

    private func updateFoundAyat() {
        debounceTimer?.invalidate()
        guard foundAyat.count != 1 else { return }

        foundAyat.removeAll()
        let normVoice = voiceText.normalizedArabic
        print("updateFoundAyat normVoice: \(normVoice)")
        guard normVoice.count > 10 else {
            print("updateFoundAyat normVoice.count <= 10")
            return
        }
        // Fast prefix check
        for (index, line) in quranLines.enumerated() {
            if line.normalizedArabic.hasPrefix(normVoice) {
                if index == 0 {
                    print("updateFoundAyat, voiceTextHasBesmillah = true")
                    voiceTextHasBesmillah = true
                } else {
                    foundAyat.append(index)
                }
            }
        }

        // Fallback with debounce if no matches
        if foundAyat.isEmpty || normVoice.count < 35 {
            print("updateFoundAyat foundAyat.isEmpty")
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.performFallbackMatch(normVoice: normVoice)
                }
            }
        }

        print("updateFoundAyat foundAyat: \(foundAyat)")
        updateQuranText()
        updateMatchedWords()
    }

    // Returns ayah index if best match from top 5 ML predictions has similarity > 85%
    func tryMLModelMatch(normVoice: String) -> Int? {
        guard let prediction = mlModel.predict(text: normVoice) else {
            return nil
        }

        print("ML Model prediction - Index: \(prediction.ayahIndex), Probability: \(prediction.probability)")
        print("Top 5 predictions:")
        for (index, prob) in prediction.top5 {
            print("  [\(index)] \(String(format: "%.2f%%", prob * 100)): \(QuranModel.shared.quranLines[index])")
        }

        // Check top 5 predictions and return the one with highest similarity to normalized voice
        //let normVoice = textToPredict.normalizedArabic
        guard !normVoice.isEmpty else {
            print("normVoice is empty, returning nil")
            return nil
        }

        var bestMatch: (index: Int, similarity: Double) = (prediction.ayahIndex, 0.0)

        for (index, _) in prediction.top5 {
            let ayahNorm = quranLines[index].normalizedArabic
            let prefix = String(ayahNorm.prefix(normVoice.count + 2))
            let similarity = normVoice.similarity(to: prefix)

            if similarity > bestMatch.similarity {
                bestMatch = (index, similarity)
            }
        }

        print("#coreml Best match: [\(bestMatch.index)] with \(String(format: "%.2f", bestMatch.similarity)) similarity - \(QuranModel.shared.quranLines[bestMatch.index])")
        if bestMatch.similarity >= 0.7 {
            return bestMatch.index
        } else {
            print("#coreml Best match rejected - similarity too low: \(String(format: "%.2f", bestMatch.similarity))")
            return nil
        }
    }

    private func performFallbackMatch(normVoice: String) {
        print("performFallbackMatch normVoice: \(normVoice)")

        var textToPredict = normVoice
        if voiceTextHasBesmillah {
            let words = normVoice.split(separator: " ")
            guard words.count > 4 else { return }
            textToPredict = words.dropFirst(4).joined(separator: " ")
        }

        // Use ML model for prediction - pass original voiceText, not normalized
        if let ayahIndex = tryMLModelMatch(normVoice: textToPredict) {
            // Strip bismillah if flag is set
            if ayahIndex == 0 {
                print("performFallbackMatch, voiceTextHasBesmillah = true")
                voiceTextHasBesmillah = true
                performFallbackMatch(normVoice: textToPredict)
                return
            }
            print("#coreml ML prediction accepted")
            foundAyat = [ayahIndex]
            updateQuranText()
            updateMatchedWords()
            return
        }

        print("#coreml ML model failed or had low similarity score")

        // If ML model fails or validation fails, fall back to similarity matching
        var bestIndex: Int?
        var bestScore = 0.0

        for (index, line) in quranLines.enumerated() {
            let lineNorm = line.normalizedArabic
            guard lineNorm.count >= textToPredict.count else { continue }

            let prefix = String(lineNorm.prefix(textToPredict.count + 2))
            let score = textToPredict.similarity(to: prefix)

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
            if score > 0.9 {
                break
            }
        }

        if let bestIndex, bestIndex > 0 {
            print("performFallbackMatch bestIndex: \(bestIndex)")
            foundAyat = [bestIndex]
            updateQuranText()
            updateMatchedWords()
        }
    }

    private func updateQuranText() {
        if let firstIndex = foundAyat.first {
            quranText = quranLines[firstIndex]

            if foundAyat.count == 1 {
                print("updateQuranText firstIndex: \(firstIndex)")
                print("updateQuranText quranLines[firstIndex]: \(quranLines[firstIndex])")
                let endIndex = min(firstIndex + 200, quranLines.count)
                let extraLines = quranLines[(firstIndex + 1)..<endIndex]
                quranText = ([quranText] + extraLines).joined(separator: " ")
            }
        }
    }

    // MARK: - Word Matching

    func updateMatchedWords() {
        guard foundAyat.count == 1 else { return }

        var results: [(String, Bool)] = matchedWords   // start with previous results
        //print("var results = matchedWords, voiceWord, quranWordsIndex: \(quranWordsIndex)")
        var quranWordsIndex = results.count - 1  // continue from last matched index
        var voiceIndex = previousVoiceWordsCount > 1 ? previousVoiceWordsCount - 2 : previousVoiceWordsCount

        print("[\(Date().logTimestamp)] voiceWords: \(voiceWords)")
        var canAdvance = true
        if voiceIndex >= voiceWords.count {
            print("voiceIndex >= voiceWords.count")
        }
        while voiceIndex < voiceWords.count {
            let voiceWord = voiceWords[voiceIndex]
            if canAdvance {
                quranWordsIndex += 1
                peekTimer?.invalidate()
                peekTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    Task { @MainActor in self?.peekHelper() }
                }
            }
            canAdvance = true
            guard quranWordsIndex < quranWords.count else {
                print("quranWordsIndex >= quranWords.count, voiceWord: \(voiceWord)")
                break
            }
            let qWord = quranWords[quranWordsIndex]
            let normQWord = qWord.normalizedArabic
            let score = voiceWord.similarity(to: normQWord)
            if score >= matchThreshold {
                print("Matched word, voiceWord: \(voiceWord), qWord: \(qWord)")
                results.append((qWord, true))
            } else { //if voiceWord.count > 3 { // ignore for short words
                if tryBackwardMatch(quranWordsIndex, voiceWord, results) {
                    canAdvance = false
                } else if voiceWord.count > 3 && tryForwardMatch(&quranWordsIndex, voiceWord, &results) {
                    // matched in forward search
                } else {
                    if score >= simiMatchThreshold {
                        print("Simimatched, voiceWord: \(voiceWord), qWord: \(qWord)")
                        results.append((qWord, true))
                    } else {
                        print("Unmatched, voiceWord: \(voiceWord), qWord: \(qWord)")
                        canAdvance = false
                    }
                }
            }
            voiceIndex += 1
        }
        matchedWords = results
        previousVoiceWordsCount = voiceWords.count
        //print("matchedWords = results, voiceWord, quranWordsIndex: \(quranWordsIndex)")
    }

    private func tryBackwardMatch(
        _ index: Int,
        _ voiceWord: String,
        _ results: [(String, Bool)]
    ) -> Bool {
        for step in 1...10 {
            guard index - step >= 0 else { break }
            let qWord = quranWords[index - step]
            if voiceWord.similarity(to: qWord.normalizedArabic) >= seekMatchThreshold {
                print("tryBackwardMatch, voiceWord: \(voiceWord), qWord: \(qWord)")
                return true
            }
        }
        return false
    }

    private func tryForwardMatch(
        _ index: inout Int,
        _ voiceWord: String,
        _ results: inout [(String, Bool)]
    ) -> Bool {
        for step in 1...17 {
            guard index + step < quranWords.count else { break }
            let qWord = quranWords[index + step]
            if voiceWord.similarity(to: qWord.normalizedArabic) >= seekMatchThreshold {
                results.append((quranWords[index], true))
                for s in 1..<step {
                    results.append((quranWords[index + s], true))
                }
                index += step
                results.append((qWord, true))
                print("tryForwardMatch, voiceWord: \(voiceWord), qWord: \(qWord)")
                return true
            } else {
                //print("tryForwardMatch no match, voiceWord: \(voiceWord), qWord: \(qWord)")
            }
        }
        return false
    }

    // MARK: - Peek Helper

    func peekHelper() {
        guard isRecording else { return }

        var results = matchedWords
        let quranWordsIndex = matchedWords.count

        if quranWordsIndex + 2 < quranWords.count {
            results.append((quranWords[quranWordsIndex], false))
            results.append((quranWords[quranWordsIndex + 1], false))
            matchedWords = results
            print("[\(Date().logTimestamp)] voiceWord, peekHelper \(quranWords[quranWordsIndex]) \(quranWords[quranWordsIndex + 1]) ")
        }
    }
}
