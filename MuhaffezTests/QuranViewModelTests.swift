//
//  QuranViewModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/19/25.
//

import Testing
@testable import Muhaffez

@MainActor
struct QuranViewModelTests {

    let quranLines = QuranModel.shared.quranLines
    let pageMarkers = QuranModel.shared.pageMarkers

    @Test func testExactMatch() async throws {
        let viewModel = QuranViewModel()
        viewModel.voiceText = "ان الله يامركم ان تؤدوا الامانات الى اهلها"
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedTrues: \(matchedTrues)")

        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))
        #expect(matchedTrues.contains("إِلىٰ"))
    }

    @Test func testFuzzyMatch() async throws {
        let viewModel = QuranViewModel()
        // Missing tashkeel + hamza variant
        viewModel.voiceText = "ان الله يامرك"
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedTrues: \(matchedTrues)")
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))

        viewModel.voiceText = "إن الله"
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))

        viewModel.voiceText = "إن"
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
    }

    @Test func testPartialRecognition() async throws {
        let viewModel = QuranViewModel()

        // Voice text that doesn't exactly match any line
        viewModel.voiceText = "الله يأمرك بالعدل"

        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedWords: \(viewModel.matchedWords)")
        print("matchedTrues: \(matchedTrues)")
        // After fallback, best match should be the first line (index 0)
        #expect(viewModel.foundAyat == [1987])

        viewModel.voiceText = "الله يأمرك تؤدوا"

        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }

        try await Task.sleep(for: .seconds(2))
        print("matchedWords: \(viewModel.matchedWords)")
        print("matchedTrues: \(matchedTrues)")
        print("viewModel.foundAyat: \(viewModel.foundAyat)")
        print("quranModel.quranLines[viewModel.foundAyat.first!]: \(viewModel.quranLines[viewModel.foundAyat.first!])")
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُ"))
    }

    @Test func testNoMatch() async throws {
        let viewModel = QuranViewModel()
        viewModel.voiceText = "hello world"
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.isEmpty)
    }

    @Test func testMatchedWordsExactMatch() async throws {
        let viewModel = QuranViewModel()
        viewModel.voiceText = "ان الله يامركم ان تؤدوا الامانات الى اهلها"
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.count == 8)
    }

    @Test func testMatchedWordsPartialMatch() async throws {
        let viewModel = QuranViewModel()
        viewModel.voiceText = "ان الله يامركم الامانة"
        try await Task.sleep(for: .seconds(2))
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("الأَماناتِ"))
    }

    @Test func testForwardMatch() async throws {
        let viewModel = QuranViewModel()

        viewModel.voiceText = "ان الله يامركم الى الامانة"
        try await Task.sleep(for: .seconds(2))
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedWords: \(viewModel.matchedWords)")
        print("matchedTrues: \(matchedTrues)")
        print("viewModel.foundAyat: \(viewModel.foundAyat)")
        print("quranLines[viewModel.foundAyat.first!]: \(quranLines[viewModel.foundAyat.first!])")
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))
        #expect(matchedTrues.contains("الأَماناتِ"))

        viewModel.voiceText = "ان الله يامركم الى"
        try await Task.sleep(for: .seconds(1.1))
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
    }

    @Test func testBesmeAllah() async throws {
        let viewModel = QuranViewModel()

        viewModel.voiceText = "بِسمِ اللَّهِ الرَّحمٰنِ الرَّحيمِ"
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(viewModel.foundAyat.count == 0)

        viewModel.voiceText = "بِسمِ اللَّهِ الرَّحمٰنِ الرَّحيمِ الم ذٰلِكَ الكِتابُ لا رَيبَ فيهِ هُدًى لِلمُتَّقينَ"
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedWords: \(viewModel.matchedWords)")
        print("matchedTrues: \(matchedTrues)")
        print("viewModel.foundAyat: \(viewModel.foundAyat)")
        print("quranLines[viewModel.foundAyat.first!]: \(quranLines[viewModel.foundAyat.first!])")
        #expect(viewModel.foundAyat.count == 1)
        #expect(viewModel.foundAyat.first! == 7)
    }

    @Test func testBackwardMatch() async throws {
        let viewModel = QuranViewModel()

        viewModel.voiceText = "ان الله يامركم يامركم "
        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))

        viewModel.voiceText = "ان الله يامركم الله"
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(!matchedTrues.contains("يَأمُرُكُم"))
    }

    @Test func testMatchedWordsWithTypos() async throws {
        let viewModel = QuranViewModel()
        viewModel.voiceText = "ان الله يامركم ان تودو الامانا إلى اهلها"
        try await Task.sleep(for: .seconds(2))
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("تُؤَدُّوا"))
        #expect(matchedTrues.contains("الأَماناتِ"))
        #expect(matchedTrues.contains("إِلىٰ"))
    }

    @Test func testMatchedWordsBelowThreshold() async throws {
        let viewModel = QuranViewModel()
        viewModel.voiceText = "سلام عالم مختلف"
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.isEmpty)
    }
}
