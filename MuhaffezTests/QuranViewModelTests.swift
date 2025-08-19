//
//  QuranViewModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/19/25.
//

import Testing
@testable import Muhaffez

struct QuranViewModelTests {
    // Example ayah for testing context
    let matchedAya = "إن الله يأمركم أن تؤدوا الأمانات إلى أهلها"

    @Test func testExactMatch() async throws {
        let viewModel = await QuranViewModel()
        await viewModel.updateRecognizedText("إِنَّ اللَّهَ يَأمُرُكُ")

        let matchedText = await viewModel.matchedText
        print("matchedText: \(matchedText)")
        await #expect(viewModel.recognizedText == "إِنَّ اللَّهَ يَأمُرُكُ")
        #expect(matchedText.contains("إِنَّ"))
        #expect(matchedText.contains("اللَّهَ"))
        #expect(matchedText.contains("يَأمُرُكُم"))
    }

    @Test func testFuzzyMatchHamzaVariants() async throws {
        let viewModel = await QuranViewModel()
        // Missing tashkeel + hamza variant
        await viewModel.updateRecognizedText("ان الله يامرك")
        await #expect(viewModel.recognizedText == "ان الله يامرك")
        var matchedText = await viewModel.matchedText
        print("matchedText: \(matchedText)")
        #expect(matchedText == "إِنَّ اللَّهَ يَأمُرُكُم")
        #expect(matchedText.contains("إِنَّ"))
        #expect(matchedText.contains("اللَّهَ"))
        #expect(matchedText.contains("يَأمُرُكُم"))

        await viewModel.updateRecognizedText("إن الله")
        matchedText = await viewModel.matchedText
        print("matchedText: \(matchedText)")
        #expect(matchedText == "إِنَّ اللَّهَ")
        #expect(matchedText.contains("إِنَّ"))
        #expect(matchedText.contains("اللَّهَ"))

        await viewModel.updateRecognizedText("إن")
        matchedText = await viewModel.matchedText
        print("matchedText: \(matchedText)")
        #expect(matchedText == "إِنَّ")
        #expect(matchedText.contains("إِنَّ"))
    }

    @Test func testPartialRecognition() async throws {
        let viewModel = await QuranViewModel()
        await viewModel.updateRecognizedText("الله يأمرك بالعدل")

        let matchedText = await viewModel.matchedText
        print("matchedText: \(matchedText)")
        #expect(matchedText.contains("اللَّهَ"))
        #expect(matchedText.contains("يَأمُرُكُم"))
        #expect(matchedText.contains("بِالعَدلِ"))
    }

    @Test func testNoMatch() async throws {
        let viewModel = await QuranViewModel()
        await viewModel.updateRecognizedText("hello world")

        await #expect(viewModel.matchedText.isEmpty)
    }

    @Test func testMatchedWordsExactMatch() async throws {
        let viewModel = await QuranViewModel()
        let recognized = "ان الله يامركم ان تؤدوا الامانات الى اهلها"
        let result = await viewModel.matchedWords(from: recognized)
        #expect(result == matchedAya)
    }

    @Test func testMatchedWordsPartialMatch() async throws {
        let viewModel = await QuranViewModel()
        let recognized = "ان الله يامركم الامانة"
        let result = await viewModel.matchedWords(from: recognized)
        // Should at least contain the key words
        #expect(result.contains("ان"))
        #expect(result.contains("الله"))
        #expect(result.contains("الامانات"))
    }

    @Test func testMatchedWordsWithTypos() async throws {
        let viewModel = await QuranViewModel()
        let recognized = "ان الله يامركم ان تودو الامانات ال اهلها"
        let result = await viewModel.matchedWords(from: recognized)
        print("result: \(result)")
        #expect(result.contains("تؤدوا"))   // typo fixed by similarity
        #expect(result.contains("الأمانات"))
        #expect(result.contains("إلى"))     // typo fixed by similarity
    }

    @Test func testMatchedWordsBelowThreshold() async throws {
        let viewModel = await QuranViewModel()
        let recognized = "سلام عالم مختلف"
        let result = await viewModel.matchedWords(from: recognized)
        #expect(result.isEmpty)   // None should pass threshold 0.7
    }

}
