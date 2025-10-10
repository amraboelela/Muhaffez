//
//  MuhaffezViewModel.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import Speech
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
                updateFoundAyat()
                updateMatchedWords()
            }
        }
    }

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

    private let initialForwardCount = 10
    private let maxForwardCount = 100
    private var forwardCount = initialForwardCount

    // MARK: - Public Actions

    func resetData() {
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
    }

    // MARK: - Aya Matching

    private func updateFoundAyat() {
        debounceTimer?.invalidate()
        guard foundAyat.count != 1 else { return }

        foundAyat.removeAll()
        let normVoice = voiceText.normalizedArabic
        guard !normVoice.isEmpty else { return }
        print("updateFoundAyat normVoice: \(normVoice)")
        // Fast prefix check
        for (index, line) in quranLines.enumerated() {
            if line.normalizedArabic.hasPrefix(normVoice) {
                foundAyat.append(index)
            }
        }

        // Fallback with debounce if no matches
        if foundAyat.isEmpty {
            print("updateFoundAyat foundAyat.isEmpty")
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.performFallbackMatch(normVoice: normVoice)
                }
            }
        }

        print("updateFoundAyat foundAyat: \(foundAyat)")
        updateQuranText()
    }

    private func performFallbackMatch(normVoice: String) {
        print("performFallbackMatch normVoice: \(normVoice)")
        var bestIndex: Int?
        var bestScore = 0.0
        let threshold = 0.6  // Skip obviously bad matches
        let voiceLen = normVoice.count
        let maxLenDiff = voiceLen / 2  // Allow 50% length difference

        for (index, line) in quranLines.enumerated() {
            let lineNorm = line.normalizedArabic

            // Skip if line is shorter than input
            guard lineNorm.count >= normVoice.count else { continue }

            // Skip if length difference is too large
            let prefix = String(lineNorm.prefix(voiceLen + 2))
            if abs(prefix.count - voiceLen) > maxLenDiff {
                continue
            }

            // Quick check: if first 3 characters don't match at all, skip Levenshtein
            let prefixCheck = min(3, voiceLen)
            let voicePrefix = String(normVoice.prefix(prefixCheck))
            let linePrefix = String(prefix.prefix(prefixCheck))
            if voicePrefix.similarity(to: linePrefix) < 0.5 {
                continue
            }

            // Now do full similarity check
            let score = normVoice.similarity(to: prefix)

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }

            // If we found a very good match, stop searching
            if score > 0.95 { break }
        }

        if let bestIndex, bestScore >= threshold {
            print("performFallbackMatch bestIndex: \(bestIndex), score: \(bestScore)")
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

        peekTimer?.invalidate()
        peekTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.peekHelper() }
        }

        var results: [(String, Bool)] = matchedWords   // start with previous results
        //print("var results = matchedWords, voiceWord, quranWordsIndex: \(quranWordsIndex)")
        var quranWordsIndex = results.count - 1  // continue from last matched index
        var voiceIndex = previousVoiceWordsCount > 0 ? previousVoiceWordsCount - 1 : previousVoiceWordsCount

        print("[\(Date().logTimestamp)] voiceWords: \(voiceWords)")
        var canAdvance = true
        if voiceIndex >= voiceWords.count {
            print("voiceIndex >= voiceWords.count")
        }
        while voiceIndex < voiceWords.count {
            let voiceWord = voiceWords[voiceIndex]
            if canAdvance {
                quranWordsIndex += 1
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
                if forwardCount > initialForwardCount {
                    forwardCount /= 2
                }
            } else { //if voiceWord.count > 3 { // ignore for short words
                if tryBackwardMatch(quranWordsIndex, voiceWord, results) {
                    canAdvance = false
                } else if voiceWord.count > 3 && tryForwardMatch(&quranWordsIndex, forwardCount, voiceWord, &results) {
                    // matched in forward search
                } else {
                    if score >= simiMatchThreshold {
                        print("Simimatched, voiceWord: \(voiceWord), qWord: \(qWord)")
                        results.append((qWord, true))
                    } else {
                        print("Unmatched, voiceWord: \(voiceWord), qWord: \(qWord)")
                        canAdvance = false
                        forwardCount = min(forwardCount * 2, maxForwardCount)
                    }
                }
            } /*else {
                print("voiceWord.count <= 3, voiceWord: \(voiceWord), qWord: \(qWord)")
                results.append((qWord, true))
                //canAdvance = false
            }*/
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
        _ count: Int,
        _ voiceWord: String,
        _ results: inout [(String, Bool)]
    ) -> Bool {
        for step in 1...count {
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
        }
        print("[\(Date().logTimestamp)] voiceWord, peekHelper \(quranWords[quranWordsIndex]) \(quranWords[quranWordsIndex + 1]) ")
    }
}
