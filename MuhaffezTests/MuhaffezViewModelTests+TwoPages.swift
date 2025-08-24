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
        let text = viewModel.rightPage.text

        // Then
        let plainText = String(text.characters)
        #expect(plainText.contains("Bismillah"))
        #expect(plainText.contains("Rahman"))
    }

    @Test("Matched and unmatched words get correct colors and separators")
    func testColoredFromMatched() async throws {
        // Given
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "بِسمِ اللَّهِ الرَّحمٰنِ الرَّحيمِ الم ذٰلِكَ الكِتابُ لا رَيبَ فيهِ هُدًى لِلمُتَّقينَ"

        // When
        let result = viewModel.leftPage.text

        // Then
        #expect(result.characters.contains { $0 == "🌼" }) // at least one separator
        let plainText = String(result.characters)
        #expect(plainText.contains("الكِتابُ"))
        #expect(plainText.contains("لِلمُتَّقينَ"))
    }

    @Test func testColoredFromMatched_addsRub3Separator() async throws {
        // Arrange
        let viewModel = MuhaffezViewModel()

        viewModel.voiceText = "إِنَّ رَبَّهُم بِهِم يَومَئِذٍ لَخَبيرٌ"
        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        var attributed = viewModel.leftPage.text
        var string = String(attributed.characters)

        // Assert
        // The rub3 separator "─" should appear because ayah at index 1 ends a rub3
        #expect(string.contains("─"))
        #expect(string.contains("القارعة"))
        
        #expect(string.contains("⭐"))

        viewModel.voiceText = "إِنَّ رَبَّهُم بِهِم يَومَئِذٍ لَخَبيرٌ القارِعَةُ"

        attributed = viewModel.leftPage.text
        string = String(viewModel.leftPage.text.characters)
        #expect(string.contains("─"))
        #expect(string.contains("🌼"))
        viewModel.isRecording = true
        // Testing the peek feature after 3 seconds
        while viewModel.leftPage.text.characters.count == attributed.characters.count {
            try await Task.sleep(for: .seconds(1))
        }
        #expect(viewModel.leftPage.text.characters.count > attributed.characters.count)
        string = String(viewModel.leftPage.text.characters)
        print("string: \(string)")
        #expect(string.contains("مَا"))

        viewModel.resetData()
        viewModel.voiceText = "عَينًا فيها تُسَمّىٰ سَلسَبيلًا"
        string = String(viewModel.rightPage.text.characters)
        #expect(string.contains("⭐"))

        viewModel.resetData()
        viewModel.voiceText = "نحن جعلناها تذكرة"
        viewModel.voiceText = "نحن جعلناها تذكرة فسبح باسم ربك العظيم"
        string = String(viewModel.leftPage.text.characters)
        #expect(string.contains("⭐"))
    }
}
