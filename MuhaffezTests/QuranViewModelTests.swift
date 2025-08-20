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
    // Example ayah for testing context
    let matchedAya = "إن الله يأمركم أن تؤدوا الأمانات إلى أهلها"

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
        viewModel.voiceText = "الله يأمرك بالعدل"

        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))
        #expect(!matchedTrues.contains("بِالعَدلِ"))

        viewModel.voiceText = "الله يأمرك تؤدوا"

        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))
        #expect(matchedTrues.contains("تُؤَدُّوا"))
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
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("الأَماناتِ"))
    }

    @Test func testForwardMatch() async throws {
        let viewModel = QuranViewModel()

        viewModel.voiceText = "ان الله يامركم الى الامانة"
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("الأَماناتِ"))

        viewModel.voiceText = "ان الله يامركم الى"
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("إِلىٰ"))
    }

    @Test func testBackwardMatch() async throws {
        let viewModel = QuranViewModel()

        viewModel.voiceText = "ان الله يامركم يامركم "
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
