//
//  QuranViewModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/19/25.
//

import Testing
@testable import Muhaffez

struct QuranViewModelTests {

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
        // Should still match the quranLine
        await #expect(viewModel.matchedText.contains("إِنَّ"))
        await #expect(viewModel.matchedText.contains("اللَّهَ"))
        await #expect(viewModel.matchedText.contains("يَأمُرُكُم"))
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
}
