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
            textToPredict = voiceText.normalizedArabic
            updateTextToPredict()
            checkA3ozoBellah()
            if !voiceText.isEmpty {
                if foundAyat.count == 1 {
                    if !updatingFoundAyat {
                        updateMatchedWords()
                    }
                } else {
                    updateFoundAyat()
                }
            }
        }
    }
    var textToPredict = "" {
        didSet {
            voiceWords = textToPredict.normalizedArabic.split(separator: " ").map { String($0) }
        }
    }
    var voiceTextHasBesmillah = false {
        didSet {
            updateTextToPredict()
        }
    }
    var voiceTextHasA3ozoBellah = false {
        didSet {
            updateTextToPredict()
        }
    }

    private func updateTextToPredict() {
        var text = voiceText.normalizedArabic
        if voiceTextHasA3ozoBellah {
            text = text.removeA3ozoBellah
        }
        if voiceTextHasBesmillah {
            text = text.removeBasmallah
        }
        textToPredict = text
        //print("updateTextToPredict textToPredict: \(textToPredict)")
    }

    var isRecording = false
    var updatingFoundAyat = false
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
        voiceTextHasA3ozoBellah = false
        voiceTextHasBesmillah = false
        updatingFoundAyat = false
    }

    func resetPages() {
        debounceTimer?.invalidate()
        quranText = ""
        matchedWords = []
        currentPageIsRight = true
        tempPage.reset()
        tempPage.isFirstPage = true
        rightPage.reset()
        leftPage.reset()
        pageCurrentLineIndex = 0
        pageMatchedWordsIndex = 0
        previousVoiceWordsCount = 0
        updatingFoundAyat = false
    }

    // MARK: - Aya Matching

    private func checkA3ozoBellah() {
        guard !textToPredict.isEmpty && !voiceTextHasA3ozoBellah else {
            return
        }
        // Check if a3ozoBellah is present (with fuzzy matching for mistakes)
        if quranModel.a3ozoBellah.hasPrefix(textToPredict) || textToPredict.hasPrefix(quranModel.a3ozoBellah) {
            print("checkA3ozoBellah, voiceTextHasA3ozoBellah = true")
            voiceTextHasA3ozoBellah = true
        } else {
            // Try fuzzy matching for common mistakes
            let similarity = textToPredict.similarity(to: quranModel.a3ozoBellah)
            if similarity >= 0.7 {
                print("checkA3ozoBellah, fuzzy match with similarity: \(similarity)")
                voiceTextHasA3ozoBellah = true
            }
        }
    }

    private func checkBismellah() {
        guard !textToPredict.isEmpty && !voiceTextHasBesmillah else {
            return
        }
        foundAyat = []

        // First pass: check if bismillah is present
        if quranModel.bismellah.hasPrefix(textToPredict) || textToPredict.hasPrefix(quranModel.bismellah) {
            print("findMatchingAyat, voiceTextHasBesmillah = true")
            voiceTextHasBesmillah = true
            // Remove bismillah from search text
            //textToPredict = textToPredict.removeBasmallah
        }
    }

    // Find ayat matching the given text using prefix matching
    private func findMatchingAyat() {
        foundAyat = []

        guard !textToPredict.isEmpty else {
            return
        }

        // Second pass: find matching ayat with cleaned text
        for (index, normLine) in quranModel.normalizedQuranLines.enumerated() {
            if normLine.hasPrefix(textToPredict) || textToPredict.hasPrefix(normLine) {
                foundAyat.append(index)
            }
        }
    }

    private func updateFoundAyat() {
        //print("updateFoundAyat")
        updatingFoundAyat = true
        debounceTimer?.invalidate()
        guard foundAyat.count != 1 else { return }

        checkA3ozoBellah()
        checkBismellah()

        //print("updateFoundAyat textToPredict: \(textToPredict)")
        guard textToPredict.count > 10 else {
            print("updateFoundAyat normVoice.count <= 10")
            foundAyat = []
            return
        }

        // Fast prefix check
        findMatchingAyat()

        if !foundAyat.isEmpty {
            for ayahIndex in foundAyat {
                print("  Found ayah [\(ayahIndex)]: \(quranLines[ayahIndex])")
            }
        }
        // Fallback with debounce if no matches
        if foundAyat.isEmpty || textToPredict.count < 17 {
            print("foundAyat.isEmpty || textToPredict.count < 17, Timer.scheduledTimer(withTimeInterval: 1.0")
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.performFallbackMatch()
                }
            }
            return
        }
        updateQuranText()
        updateMatchedWords()
        updatingFoundAyat = false
    }

    func checkCoreMLResults() {
        print("checkCoreMLResults")
        guard !foundAyat.isEmpty else {
            print("checkCoreMLResults, foundAyat.isEmpty, returning")
            return
        }
        var bestMatch: (index: Int, similarity: Double) = (foundAyat.first!, 0.0)
        updateTextToPredict()

        for index in foundAyat {
            let ayahNorm = quranLines[index].normalizedArabic
            let ayahPrefix = String(ayahNorm.prefix(textToPredict.count))
            let textPrefix = String(textToPredict.prefix(ayahPrefix.count))
            let similarity = textPrefix.similarity(to: ayahPrefix)

            if similarity > bestMatch.similarity {
                bestMatch = (index, similarity)
            }
        }

        print("#coreml Best match: [\(bestMatch.index)] with \(String(format: "%.2f", bestMatch.similarity)) similarity - \(QuranModel.shared.quranLines[bestMatch.index])")
        if bestMatch.similarity >= 0.6 {
            foundAyat = [bestMatch.index]
        } else {
            foundAyat = []
            print("#coreml Best match rejected - similarity too low: \(String(format: "%.2f", bestMatch.similarity))")
        }
    }

    // Uses transformer model prediction + prefix matching to update foundAyat
    func tryMLModelMatch() {
        print("tryMLModelMatch")

        // Cap input to first 6 words to match model's training expectations
        let inputWords = textToPredict.normalizedArabic
        guard let predictedText = mlModel.predict(text: inputWords) else {
            print("ML Model prediction failed")
            foundAyat = []
            return
        }
        print("ML Model predicted text: \(predictedText)")
        textToPredict = predictedText
        checkA3ozoBellah()
        checkBismellah()

        // Use the predicted text to find matching ayat using prefix matching
        // Predicted text is already normalized
        guard !textToPredict.isEmpty else {
            print("Predicted text is empty")
            return
        }

        // Try matching with full prediction first, then progressively trim words from the end
        // Stop when we have at least 3 words or find a match
        let predictedWords = textToPredict.split(separator: " ").map { String($0) }
        let minWords = 3

        for wordCount in stride(from: predictedWords.count, through: minWords, by: -1) {
            let trimmedWords = predictedWords.prefix(wordCount)
            let trimmedText = trimmedWords.joined(separator: " ")

            print("#coreml Trying with \(wordCount) words: \(trimmedText)")

            // Find ayat that match the trimmed prefix
            textToPredict = trimmedText
            findMatchingAyat()

            // If we found matches, return
            if !foundAyat.isEmpty {
                print("#coreml Found \(foundAyat.count) match(es) with \(wordCount) words")
                print("#coreml Updated foundAyat with \(foundAyat.count) matches")
                for ayahIndex in foundAyat {
                    print("#coreml found ayah [\(ayahIndex)]: \(quranLines[ayahIndex])")
                }
                checkCoreMLResults()
                return
            }
            print("#coreml No matches found with \(wordCount) words, trying with fewer words...")
        }
        print("#coreml No matches found after trying all word counts")
    }

    private func performFallbackMatch() {
//        defer {
//            updatingFoundAyat = false
//            print("updatingFoundAyat = false")
//        }
        print("performFallbackMatch textToPredict: \(textToPredict)")

        // Use ML model for prediction
        tryMLModelMatch()

        if foundAyat.count == 1 {
            print("#coreml ML prediction got one ayah: \(foundAyat)")
            if let first = foundAyat.first, first == 0 {
                voiceTextHasA3ozoBellah = true
                foundAyat = []
                updatingFoundAyat = false
                return
            }
            if let first = foundAyat.first, first == 1 {
                voiceTextHasBesmillah = true
                foundAyat = []
                updatingFoundAyat = false
                return
            }
            updateQuranText()
            updateMatchedWords()
            updatingFoundAyat = false
            return
        }
        //print("#coreml ML model failed, falling back to similarity matching")
        print("Starting similarity matching")
        updateTextToPredict()

        // Use background similarity matching
        Task.detached { [weak self] in
            await self?.performSimilarityMatching()
        }
    }

    private func performSimilarityMatching() async {
        // Capture values we need on main thread
        let textToPredict = self.textToPredict
        let normalizedQuranLines = quranModel.normalizedQuranLines
        let quranLines = self.quranLines
        let currentFoundAyat = self.foundAyat

        // Perform expensive computation on background thread
        var bestIndex: Int?
        var bestScore = 0.0

        for (index, ayahNorm) in normalizedQuranLines.enumerated() {
            let ayahPrefix = String(ayahNorm.prefix(textToPredict.count))
            let textPrefix = String(textToPredict.prefix(ayahPrefix.count))
            let similarity = textPrefix.similarity(to: ayahPrefix)

            if similarity > bestScore {
                bestScore = similarity
                bestIndex = index
            }
            if similarity > 0.9 {
                print("Early break at index \(index): \(quranLines[index])")
                print("  similarity: \(String(format: "%.2f", similarity))")
                break
            }
        }

        // Return to main thread to update UI
        await MainActor.run {
            if let bestIndex, bestIndex > 0 {
                print("performFallbackMatch bestIndex: \(bestIndex)")
                print("performFallbackMatch bestIndex ayah: \(quranLines[bestIndex])")
                if bestIndex == currentFoundAyat.first {
                    print("Similarity match found the same ayah")
                    return
                }
                self.resetPages()
                self.foundAyat = [bestIndex]
                self.updateQuranText()
                self.updateMatchedWords()
                updatingFoundAyat = false
            }
        }
    }

    private func updateQuranText() {
        if let firstIndex = foundAyat.first {
            quranText = quranLines[firstIndex]

            if foundAyat.count == 1 {
                print("updateQuranText firstIndex: \(firstIndex)")
                print("updateQuranText quranLines[firstIndex]: \(quranLines[firstIndex])")
                let endIndex = min(firstIndex + 500, quranLines.count)
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
        print("updateMatchedWords, matchedWords = results, matchedWords: \(matchedWords)")
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
