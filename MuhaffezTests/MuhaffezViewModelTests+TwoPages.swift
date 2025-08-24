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

        let result = viewModel.leftPage.textString

        print("result: \(result)")
        #expect(result.contains("سورة البقرة"))
        #expect(result.contains("الكِتابُ"))
        #expect(result.contains("لِلمُتَّقينَ"))
    }

    @Test func testColoredFromMatched_addsRub3Separator() async throws {
        // Arrange
        let viewModel = MuhaffezViewModel()

        viewModel.voiceText = "إِنَّ رَبَّهُم بِهِم يَومَئِذٍ لَخَبيرٌ"
        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        //var attributed = viewModel.leftPage.text
        var textString = viewModel.leftPage.textString

        // Assert
        // The rub3 separator "─" should appear because ayah at index 1 ends a rub3
        #expect(textString.contains("─"))
        #expect(textString.contains("القارعة"))

        #expect(textString.contains("⭐"))

        viewModel.voiceText = "إِنَّ رَبَّهُم بِهِم يَومَئِذٍ لَخَبيرٌ القارِعَةُ"

        textString = viewModel.leftPage.textString
        #expect(textString.contains("─"))
        #expect(textString.contains("🌼"))
        viewModel.isRecording = true
        // Testing the peek feature after 3 seconds
        while viewModel.leftPage.textString.count == textString.count {
            try await Task.sleep(for: .seconds(1))
        }
        #expect(viewModel.leftPage.textString.count > textString.count)
        textString = viewModel.leftPage.textString
        print("textString: \(textString)")
        #expect(textString.contains("مَا"))

        viewModel.resetData()
        viewModel.voiceText = "عَينًا فيها تُسَمّىٰ سَلسَبيلًا"
        textString = viewModel.rightPage.textString
        #expect(textString.contains("⭐"))

        viewModel.resetData()
        viewModel.voiceText = "نحن جعلناها تذكرة"
        viewModel.voiceText = "نحن جعلناها تذكرة فسبح باسم ربك العظيم"
        textString = viewModel.leftPage.textString
        #expect(textString.contains("⭐"))
    }
}
