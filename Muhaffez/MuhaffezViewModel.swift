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
    var matchedWords: [(String, Bool)] = [] {
        didSet {
            updatePages()
        }
    }
    var foundAyat = [Int]()

    var quranText = "" {
        didSet {
            quranWords = quranText.split(separator: " ").map { String($0) }
        }
    }

    var quranWords = [String]()
    var voiceWords = [String]()
    var tempRightPage = PageModel()
    var tempLeftPage = PageModel()
    var rightPage = PageModel()
    var leftPage = PageModel()
    var voicePageNumber = 1
    var currentPageIsRight = true {
        didSet {
            if currentPageIsRight {
                withAnimation {
                    tempLeftPage.reset()
                }
            }
            if !oldValue && currentPageIsRight {
                rightPage.reset()
            }
        }
    }

    let quranLines = QuranModel.shared.quranLines
    let pageMarkers = QuranModel.shared.pageMarkers
    let rub3Markers = QuranModel.shared.rub3Markers
    let surahMarkers = QuranModel.shared.surahMarkers

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var debounceTimer: Timer?
    private var peekTimer: Timer?
    private let matchThreshold = 0.6
    private let seekMatchThreshold = 0.7

    // MARK: - Public Actions

    func resetData() {
        foundAyat.removeAll()
        quranText = ""
        matchedWords = []
        voiceText = ""
        voicePageNumber = 1
        currentPageIsRight = true
        tempRightPage.reset()
        tempLeftPage.reset()
        rightPage.reset()
        leftPage.reset()
    }

    // MARK: - Aya Matching

    private func updateFoundAyat() {
        guard foundAyat.count != 1 else { return }

        foundAyat.removeAll()
        let normVoice = voiceText.normalizedArabic
        guard !normVoice.isEmpty else { return }
        
        // Fast prefix check
        for (index, line) in quranLines.enumerated() {
            if line.normalizedArabic.hasPrefix(normVoice) {
                foundAyat.append(index)
            }
        }

        // Fallback with debounce if no matches
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
            foundAyat = [bestIndex]
            updateQuranText()
            updateMatchedWords()
        }
    }

    private func updateQuranText() {
        if let firstIndex = foundAyat.first {
            quranText = quranLines[firstIndex]

            if foundAyat.count == 1 {
                let endIndex = min(firstIndex + 100, quranLines.count)
                let extraLines = quranLines[(firstIndex + 1)..<endIndex]
                quranText = ([quranText] + extraLines).joined(separator: " ")
            }
        }
    }

    // MARK: - Word Matching

    func updateMatchedWords() {
        guard foundAyat.count == 1 else { return }

        peekTimer?.invalidate()
        peekTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.peekHelper() }
        }

        var results: [(String, Bool)] = []
        var quranWordsIndex = -1

        //print("voiceWords: \(voiceWords)")
        for voiceWord in voiceWords {
            quranWordsIndex += 1
            guard quranWordsIndex < quranWords.count else { break }

            let qWord = quranWords[quranWordsIndex]
            let normQWord = qWord.normalizedArabic
            let score = voiceWord.similarity(to: normQWord)

            // Direct match
            if score >= matchThreshold {
                results.append((qWord, true))
                continue
            }

            // Try backward and forward search
            if tryBackwardMatch(voiceWord) { continue }
            if tryForwardMatch(voiceWord) { continue }

            results.append((quranWords[quranWordsIndex], false))
        }

        matchedWords = results
        //print("matchedWords: \(matchedWords)")

        func tryBackwardMatch(_ voiceWord: String) -> Bool {
            var index = quranWordsIndex
            for step in 1...3 {
                guard quranWordsIndex - step >= 0 else { break }
                let qWord = quranWords[index - step]
                if voiceWord.similarity(to: qWord.normalizedArabic) >= seekMatchThreshold {
                    index -= step
                    results[index].1 = true
                    return true
                }
            }
            return false
        }

        func tryForwardMatch(_ voiceWord: String) -> Bool {
            for step in 1...3 {
                guard quranWordsIndex + step < quranWords.count else { break }
                let qWord = quranWords[quranWordsIndex + step]
                if voiceWord.similarity(to: qWord.normalizedArabic) >= seekMatchThreshold {
                    results.append((quranWords[quranWordsIndex], false))
                    for s in 1..<step {
                        results.append((quranWords[quranWordsIndex + s], false))
                    }
                    quranWordsIndex += step
                    results.append((qWord, true))
                    return true
                }
            }
            return false
        }
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
    }
}

