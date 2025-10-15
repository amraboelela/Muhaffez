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

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should return index 0 (Al-Fatiha first ayah)
    #expect(result != nil)
    if let index = result {
      #expect(index == 0)
    }
  }

  @Test("ML Model returns valid index for An-Nas")
  func testMLModelAnNas() async throws {
    let viewModel = MuhaffezViewModel()
    let voiceText = "قل اعوذ برب الناس"

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should return index for Surat An-Nas (last surah)
    #expect(result != nil)
    if let index = result {
      #expect(index >= 6200)  // Near end of Quran
    }
  }

  @Test("ML Model returns valid index for Al-Baqara 255 (Ayat Al-Kursi)")
  func testMLModelAyatAlKursi() async throws {
    let viewModel = MuhaffezViewModel()
    let voiceText = "الله لا اله الا هو الحي القيوم"

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should return a valid ayah index
    #expect(result != nil)
    if let index = result {
      #expect(index >= 0 && index < 6203)
    }
  }

  @Test("ML Model returns valid index for partial ayah")
  func testMLModelPartialAyah() async throws {
    let viewModel = MuhaffezViewModel()
    let voiceText = "الحمد لله رب"

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should return index 1 (Al-Fatiha second ayah) or close
    #expect(result != nil)
    if let index = result {
      #expect(index >= 0 && index < 10)  // Should be in early ayat
    }
  }

  @Test("ML Model returns nil for non-Quranic text")
  func testMLModelNonQuranicText() async throws {
    let viewModel = MuhaffezViewModel()
    let voiceText = "hello world this is not arabic"

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should return nil (low probability)
    #expect(result == nil)
  }

  @Test("ML Model handles distorted text")
  func testMLModelDistortedText() async throws {
    let viewModel = MuhaffezViewModel()
    // Distorted version of "بسم الله الرحمن الرحيم"
    let voiceText = "بسم اله الرحمن الرحم"

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should still find Al-Fatiha (trained with distortions)
    #expect(result != nil)
    if let index = result {
      #expect(index >= 0 && index < 20)  // Should be in early ayat
    }
  }

  @Test("ML Model handles offset text (starting from 2nd word)")
  func testMLModelOffsetText() async throws {
    let viewModel = MuhaffezViewModel()
    // "الله الرحمن الرحيم" (starting from 2nd word)
    let voiceText = "الله الرحمن الرحيم"

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should still find Al-Fatiha (trained with offsets)
    #expect(result != nil)
    if let index = result {
      #expect(index >= 0 && index < 20)  // Should be in early ayat
    }
  }

  @Test("ML Model returns nil for empty string")
  func testMLModelEmptyString() async throws {
    let viewModel = MuhaffezViewModel()
    let voiceText = ""

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should return nil or low probability
    #expect(result == nil)
  }

  @Test("ML Model handles long input (70+ characters)")
  func testMLModelLongInput() async throws {
    let viewModel = MuhaffezViewModel()
    let voiceText = "ان الله يامركم ان تؤدوا الامانات الى اهلها واذا حكمتم بين الناس ان تحكموا بالعدل"

    let result = viewModel.tryMLModelMatch(voiceText: voiceText)

    // Should truncate to 70 chars and still find match
    #expect(result != nil)
    if let index = result {
      #expect(index >= 0 && index < 6203)
    }
  }
}
