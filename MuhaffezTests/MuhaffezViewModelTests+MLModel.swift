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
        viewModel.textToPredict = "بسم الله الرحمن الرحيم"

        viewModel.tryMLModelMatch()

        #expect(viewModel.foundAyat.isEmpty)
        // Should detect bismillah and set voiceTextHasBesmillah
        #expect(viewModel.voiceTextHasBesmillah == true)
    }

    @Test func testAnNas() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.textToPredict = "قل اعوذ برب الناس"
        viewModel.tryMLModelMatch()

        // Should update foundAyat with index 6198 (An-Nas)
        #expect(viewModel.foundAyat.contains(6198))
        #expect(viewModel.foundAyat.count == 1)
    }

    @Test func testAlMaidah51() async throws {
        let viewModel = MuhaffezViewModel()
        // Missing first word "يا" - tests model's robustness to partial input
        let textToPredict = "أَيُّهَا الَّذينَ آمَنوا لا تَتَّخِذُوا اليَهودَ وَالنَّصارىٰ أَولِياءَ بَعضُهُم أَولِياءُ بَعضٍ"
        viewModel.textToPredict = textToPredict
        viewModel.tryMLModelMatch()

        // Should update foundAyat with index 409 (first match)
        #expect(viewModel.foundAyat.first == 409)
        #expect(viewModel.foundAyat.count == 6)

        viewModel.voiceText = textToPredict
        while viewModel.foundAyat.isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }
        #expect(viewModel.foundAyat.first == 718)
        #expect(viewModel.foundAyat.count == 1)
    }

    @Test func testAyatAlKursi() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.textToPredict = "الله لا اله الا هو الحي القيوم"
        viewModel.tryMLModelMatch()

        #expect(viewModel.foundAyat.first == 261)
        #expect(viewModel.foundAyat.count == 1)
    }

    @Test func testPartialAyah() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.textToPredict = "الحمد لله رب"
        viewModel.tryMLModelMatch()

        #expect(viewModel.foundAyat.first == 2)
        #expect(viewModel.foundAyat.count == 1)
    }

    @Test func testNonQuranicText() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.textToPredict = "hello world this is not arabic"
        viewModel.tryMLModelMatch()

        // Neural network will not find matches for non-Quranic text
        #expect(viewModel.foundAyat.isEmpty)
    }

    @Test func testDistortedText() async throws {
        let viewModel = MuhaffezViewModel()
        // Distorted version of "بسم الله الرحمن الرحيم"
        viewModel.textToPredict = "بسم اله الرحمن الرحم"
        viewModel.tryMLModelMatch()

        #expect(viewModel.foundAyat.isEmpty)
        #expect(viewModel.voiceTextHasBesmillah)
    }

    @Test func testOffsetText() async throws {
        let viewModel = MuhaffezViewModel()
        // Test with partial ayah (last part of Al-Fatiha first ayah)
        viewModel.textToPredict = "الرحمن الرحيم"
        viewModel.tryMLModelMatch()

        #expect(viewModel.foundAyat.first == 3)
        #expect(viewModel.foundAyat.count == 1)
    }

    @Test func testEmptyString() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.textToPredict = ""

        viewModel.tryMLModelMatch()

        // Empty string results in empty normalized text, so foundAyat remains empty
        #expect(viewModel.foundAyat.isEmpty)
    }

    @Test func testLongInput() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.textToPredict = "ان الله يامركم ان تؤدوا الامانات الى اهلها واذا حكمتم بين الناس ان تحكموا بالعدل"

        viewModel.tryMLModelMatch()

        #expect(viewModel.foundAyat.first == 549)
        #expect(viewModel.foundAyat.count == 1)
    }
}
