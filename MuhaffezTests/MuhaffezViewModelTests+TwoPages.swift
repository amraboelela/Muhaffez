//
//  MuhaffezViewModelTests+TwoPages.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/23/25.
//

import Testing
@testable import Muhaffez

@MainActor
struct MuhaffezViewModelTwoPagesTests {

    @Test("Display text builds correctly from foundAyat")
    func testDisplayText() async throws {
        // Given
        let viewModel = MuhaffezViewModel()
        //viewModel.quranLines = ["Bismillah ir Rahman ir Rahim"]
        viewModel.foundAyat = [0]
        viewModel.matchedWords = [("Bismillah", true), ("Rahman", false)]

        // When
        let text = viewModel.displayText

        // Then
        let plainText = String(text.characters)
        #expect(plainText.contains("Bismillah"))
        #expect(plainText.contains("Rahman"))
    }

    @Test("Matched and unmatched words get correct colors and separators")
    func testColoredFromMatched() async throws {
        // Given
        let viewModel = MuhaffezViewModel()
        let quranLines = [
            "Bismillah ir Rahman ir Rahim",
            "Alhamdulillahi Rabbil Alamin"
        ]
        let matches: [(String, Bool)] = [
            ("Bismillah", true),
            ("ir", true),
            ("Rahman", false),
            ("ir", true),
            ("Rahim", true),
            ("Alhamdulillahi", true),
            ("Rabbil", false),
            ("Alamin", true)
        ]

        // When
        let result = viewModel.coloredFromMatched(
            matches: matches,
            quranLines: quranLines,
            firstIndex: 0
        )

        // Then
        #expect(result.characters.contains { $0 == "🌸" }) // at least one separator
        let plainText = String(result.characters)
        #expect(plainText.contains("Bismillah"))
        #expect(plainText.contains("Rahman"))


    }
}
