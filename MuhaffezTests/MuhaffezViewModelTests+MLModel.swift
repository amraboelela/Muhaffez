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

    @Test("ML Model returns valid index for Al-Fatiha")
    func testMLModelAlFatiha() async throws {
        let viewModel = MuhaffezViewModel()
        // Pass raw text (with tashkeel) as the model was trained on raw text
        let voiceText = "بسم الله الرحمن الرحيم"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Should return index 0 (Al-Fatiha first ayah)
        #expect(index == 0)
    }

    @Test("ML Model returns valid index for An-Nas")
    func testMLModelAnNas() async throws {
        let viewModel = MuhaffezViewModel()
        let voiceText = "قل اعوذ برب الناس"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(index == 6197)  // First ayah of An-Nas
    }

    @Test("ML Model returns valid index for Al-Ma'idah 51 (missing first word)")
    func testMLModelAlMaidah51() async throws {
        let viewModel = MuhaffezViewModel()
        // Missing first word "يا" - tests model's robustness to partial input
        let voiceText = "أَيُّهَا الَّذينَ آمَنوا لا تَتَّخِذُوا اليَهودَ وَالنَّصارىٰ أَولِياءَ بَعضُهُم أَولِياءُ بَعضٍ"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Should return index 717 (Al-Ma'idah:51)
        #expect(index == 717)  // Al-Ma'idah:51
    }

    @Test("ML Model returns valid index for Al-Baqara 255 (Ayat Al-Kursi)")
    func testMLModelAyatAlKursi() async throws {
        let viewModel = MuhaffezViewModel()
        let voiceText = "الله لا اله الا هو الحي القيوم"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Should return a valid ayah index
        #expect(index != nil)
        if let index {
            #expect(index >= 0 && index < 6203)
        }
    }

    @Test("ML Model returns valid index for partial ayah")
    func testMLModelPartialAyah() async throws {
        let viewModel = MuhaffezViewModel()
        let voiceText = "الحمد لله رب"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Should return index 1 (Al-Fatiha second ayah) or close
        #expect(index == 1)  // Should be in early ayat
    }

    @Test("ML Model returns result for non-Quranic text")
    func testMLModelNonQuranicText() async throws {
        let viewModel = MuhaffezViewModel()
        let voiceText = "hello world this is not arabic"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Neural network will return nil if similarity is too low
        // This is expected behavior - validation happens within ML matching
        #expect(index == nil)
    }

    @Test("ML Model handles distorted text")
    func testMLModelDistortedText() async throws {
        let viewModel = MuhaffezViewModel()
        // Distorted version of "بسم الله الرحمن الرحيم"
        let voiceText = "بسم اله الرحمن الرحم"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Should still find Al-Fatiha (trained with distortions)
        #expect(index == 0)  // Should be in early ayat
    }

    @Test("ML Model handles offset text (starting from 2nd word)")
    func testMLModelOffsetText() async throws {
        let viewModel = MuhaffezViewModel()
        // Test with partial ayah (last part of Al-Fatiha first ayah)
        let voiceText = "الرحمن الرحيم"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Model may not find exact match since this is just a fragment
        // Just verify it returns a valid index
        #expect(index == 2)
    }

    @Test("ML Model handles empty string")
    func testMLModelEmptyString() async throws {
        let viewModel = MuhaffezViewModel()
        let voiceText = ""

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Empty string results in empty normalized text, so we return nil
        #expect(index == nil)
    }

    @Test("ML Model handles long input (70+ characters)")
    func testMLModelLongInput() async throws {
        let viewModel = MuhaffezViewModel()
        let voiceText = "ان الله يامركم ان تؤدوا الامانات الى اهلها واذا حكمتم بين الناس ان تحكموا بالعدل"

        let index = viewModel.tryMLModelMatch(normVoice: voiceText.normalizedArabic)

        // Should truncate to 70 chars and still find match
        #expect(index == 548)
    }
}
