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
    private let seekMatchThreshold = 0.95

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

        for (index, line) in quranLines.enumerated() {
            let lineNorm = line.normalizedArabic
            guard lineNorm.count >= normVoice.count else { continue }

            let prefix = String(lineNorm.prefix(normVoice.count + 2))
            let score = normVoice.similarity(to: prefix)

            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
            if score > 0.9 { break }
        }

        if let bestIndex {
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

        peekTimer?.invalidate()
        peekTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.peekHelper() }
        }

        var results: [(String, Bool)] = matchedWords   // start with previous results
        //print("var results = matchedWords, voiceWord, quranWordsIndex: \(quranWordsIndex)")
        var quranWordsIndex = results.count - 1  // continue from last matched index
        var voiceIndex = results.count            // resume at the same position

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
                print("score >= matchThreshold, voiceWord: \(voiceWord), qWord: \(qWord)")
                results.append((qWord, true))
            } else { //if voiceWord.count > 3 { // ignore for short words
                if tryBackwardMatch(quranWordsIndex, voiceWord, results) {
                    canAdvance = false
                } else if voiceWord.count > 3 && tryForwardMatch(&quranWordsIndex, voiceWord, &results) {
                    // matched in forward search
                } else {
                    print("unmatched, voiceWord: \(voiceWord), qWord: \(qWord)")
                    results.append((qWord, true))
                }
            } /*else {
                print("voiceWord.count <= 3, voiceWord: \(voiceWord), qWord: \(qWord)")
                results.append((qWord, true))
                //canAdvance = false
            }*/
            voiceIndex += 1
        }
        matchedWords = results
        //print("matchedWords = results, voiceWord, quranWordsIndex: \(quranWordsIndex)")
    }

    private func tryBackwardMatch(
        _ index: Int,
        _ voiceWord: String,
        _ results: [(String, Bool)]
    ) -> Bool {
        for step in 1...7 {
            guard index - step >= 0 else { break }
            let qWord = quranWords[index - step]
            if voiceWord.similarity(to: qWord.normalizedArabic) >= seekMatchThreshold {
                //index -= step
                //results.removeLast(step)
                //results.append((qWord, true))
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
        for step in 1...7 {
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
