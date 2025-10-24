//
//  MuhaffezViewModelTests+MLModel.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 10/14/25.
//

import Testing
@testable import Muhaffez

@MainActor
struct MLModelTests {

    @Test func testAlFatiha() async throws {
        let viewModel = MuhaffezViewModel()
        // Pass raw text (with tashkeel) as the model was trained on raw text
        viewModel.voiceText = "بسم الله الرحمن الرحيم"

        let index = viewModel.tryMLModelMatch()

        // Should return index 0 (Al-Fatiha first ayah)
        #expect(index == 0)
    }

    @Test func testAnNas() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "قل اعوذ برب الناس"

        let index = viewModel.tryMLModelMatch()

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(index == 6197)  // First ayah of An-Nas
    }

    @Test func testAlMaidah51() async throws {
        let viewModel = MuhaffezViewModel()
        // Missing first word "يا" - tests model's robustness to partial input
        viewModel.voiceText = "أَيُّهَا الَّذينَ آمَنوا لا تَتَّخِذُوا اليَهودَ وَالنَّصارىٰ أَولِياءَ بَعضُهُم أَولِياءُ بَعضٍ"

        let index = viewModel.tryMLModelMatch()

        // Should return index 717 (Al-Ma'idah:51)
        #expect(index == 717)  // Al-Ma'idah:51
    }

    @Test func testAyatAlKursi() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "الله لا اله الا هو الحي القيوم"

        let index = viewModel.tryMLModelMatch()

        // Should return a valid ayah index
        #expect(index != nil)
        if let index {
            #expect(index >= 0 && index < 6203)
        }
    }

    @Test func testPartialAyah() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "الحمد لله رب"

        let index = viewModel.tryMLModelMatch()

        // Should return index 1 (Al-Fatiha second ayah) or close
        #expect(index == 1)  // Should be in early ayat
    }

    @Test func testNonQuranicText() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "hello world this is not arabic"

        let index = viewModel.tryMLModelMatch()

        // Neural network will return nil if similarity is too low
        // This is expected behavior - validation happens within ML matching
        #expect(index == nil)
    }

    @Test func testDistortedText() async throws {
        let viewModel = MuhaffezViewModel()
        // Distorted version of "بسم الله الرحمن الرحيم"
        viewModel.voiceText = "بسم اله الرحمن الرحم"

        let index = viewModel.tryMLModelMatch()

        // Should still find Al-Fatiha (trained with distortions)
        #expect(index == 0)  // Should be in early ayat
    }

    @Test func testOffsetText() async throws {
        let viewModel = MuhaffezViewModel()
        // Test with partial ayah (last part of Al-Fatiha first ayah)
        viewModel.voiceText = "الرحمن الرحيم"

        let index = viewModel.tryMLModelMatch()

        // Model may not find exact match since this is just a fragment
        // Just verify it returns a valid index
        #expect(index == 2)
    }

    @Test func testEmptyString() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = ""

        let index = viewModel.tryMLModelMatch()

        // Empty string results in empty normalized text, so we return nil
        #expect(index == nil)
    }

    @Test func testLongInput() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "ان الله يامركم ان تؤدوا الامانات الى اهلها واذا حكمتم بين الناس ان تحكموا بالعدل"

        let index = viewModel.tryMLModelMatch()

        // Should truncate to 70 chars and still find match
        #expect(index == 548)
    }
}
