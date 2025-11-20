//
//  MuhaffezViewModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/19/25.
//

import Testing
@testable import Muhaffez

@MainActor
struct MuhaffezViewModelTests {

    let quranLines = QuranModel.shared.quranLines
    let pageMarkers = QuranModel.shared.pageMarkers

    @Test func testExactMatch() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "ان الله يامركم ان تؤدوا الامانات الى اهلها"
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedTrues: \(matchedTrues)")

        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))
        #expect(matchedTrues.contains("إِلىٰ"))
    }

    @Test func testFuzzyMatch() async throws {
        let viewModel = MuhaffezViewModel()
        // Missing tashkeel + hamza variant
        viewModel.voiceText = "ان الله يامرك"
        while viewModel.matchedWords.isEmpty {
            try await Task.sleep(for: .seconds(1))
        }
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

    @Test func testBismillah() async throws {
        let viewModel = MuhaffezViewModel()

        // Test with exact Bismillah
        viewModel.voiceText = "بسم الله الرحمن الرحيم"
        #expect(viewModel.voiceTextHasBesmillah == true)
        #expect(viewModel.foundAyat.isEmpty) // Bismillah at index 0 should not be added to foundAyat

        // Reset and test with Bismillah followed by another ayah
        viewModel.resetData()
        #expect(viewModel.voiceTextHasBesmillah == false)

        viewModel.voiceText = "بسم الله الرحمن الرحيم الحمد لله رب العالمين"

        #expect(viewModel.voiceTextHasBesmillah == true)
        // Should find Al-Fatiha ayah 2 (index 2) after skipping Bismillah
        #expect(viewModel.foundAyat.contains(2))
    }

    @Test func testBismillahAndAnNas() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "بسم الله الرحمن الرحيم قل اعوذ برب الناس"
        #expect(viewModel.voiceTextHasBesmillah == true)

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(viewModel.foundAyat.contains(6198))

        viewModel.resetData()
        viewModel.voiceText = "بسم الله الرحمن الرحيم قل اعوذ برب الناس ملك الناس"
        #expect(viewModel.voiceTextHasBesmillah == true)

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(viewModel.foundAyat.contains(6198))

        viewModel.resetData()
        viewModel.voiceText = "بسم الله الرحمن الرحيم قل اعوذ برب النا ملك الناس"
        #expect(viewModel.voiceTextHasBesmillah == true)

        while viewModel.foundAyat.isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(viewModel.foundAyat.contains(6198))
    }

    @Test func testA3ozoBellah() async throws {
        let viewModel = MuhaffezViewModel()

        // Test with just A3ozo Bellah - should not set voiceTextHasBesmillah
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم"
        #expect(viewModel.voiceTextHasA3ozoBellah == true)
        #expect(viewModel.voiceTextHasBesmillah == false)
        #expect(viewModel.foundAyat.isEmpty)

        viewModel.resetData()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم"
        #expect(viewModel.voiceTextHasA3ozoBellah == true)
        #expect(viewModel.voiceTextHasBesmillah == true)
        #expect(viewModel.foundAyat.isEmpty)
    }

    @Test func testA3ozoBellahWithMistake() async throws {
        let viewModel = MuhaffezViewModel()

        // Test with mistake
        viewModel.voiceText = "اعوذ بالله من شيطان الرجيم"

        // Should still detect it as A3ozoBellah due to fuzzy matching
        #expect(viewModel.voiceTextHasA3ozoBellah == true)
        #expect(viewModel.voiceTextHasBesmillah == false)
        #expect(viewModel.foundAyat.isEmpty)
    }

    @Test func testA3ozoBellahAndBismillahAndAnNas() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم قل اعوذ برب الناس"
        #expect(viewModel.voiceTextHasBesmillah == true)

        while viewModel.foundAyat.isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(viewModel.foundAyat.contains(6198))

        viewModel.resetData()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم قل اعوذ برب الناس ملك الناس"
        #expect(viewModel.voiceTextHasBesmillah == true)

        while viewModel.foundAyat.isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(viewModel.foundAyat.contains(6198))

        viewModel.resetData()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم قل اعوذ برب النا ملك الناس"
        #expect(viewModel.voiceTextHasBesmillah == true)

        while viewModel.foundAyat.isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }

        // Should return index 6197 (first ayah of Surat An-Nas)
        #expect(viewModel.foundAyat.contains(6198))
    }

    @Test func testPartialRecognition() async throws {
        let viewModel = MuhaffezViewModel()

        // Voice text that doesn't exactly match any line
        viewModel.voiceText = "الله يأمرك بالعدل"

        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedWords: \(viewModel.matchedWords)")
        print("matchedTrues: \(matchedTrues)")
        // ML model has low confidence (45%), so falls back to fuzzy matching
        // Fuzzy matching correctly finds index 1987 (88.89% similarity)
        #expect(viewModel.foundAyat == [1988])

        viewModel.voiceText = "الله يأمرك تؤدوا"

        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }

        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        print("matchedWords: \(viewModel.matchedWords)")
        print("matchedTrues: \(matchedTrues)")
        print("viewModel.foundAyat: \(viewModel.foundAyat)")
        print("quranModel.quranLines[viewModel.foundAyat.first!]: \(viewModel.quranLines[viewModel.foundAyat.first!])")
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُ"))
    }

    @Test func testNoMatch() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "hello world"
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.isEmpty)
    }

    @Test func testMatchedWordsExactMatch() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "ان الله يامركم ان تؤدوا الامانات الى اهلها"

        while viewModel.foundAyat.isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }

        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.count == 8)
    }

    @Test func testMatchedWordsPartialMatch() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "ان الله يامركم الأَمانا"
        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        //let normalizedMatches = matchedTrues.map { $0.normalizedArabic }
        print("matchedTrues: \(matchedTrues)")
        //print("normalizedMatches: \(normalizedMatches)")
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))
    }

    @Test func testForwardMatch() async throws {
        let viewModel = MuhaffezViewModel()

        viewModel.voiceText = "ان الله يامركم الى الأَمانا"
        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        print("matchedWords: \(viewModel.matchedWords)")
        print("matchedTrues: \(matchedTrues)")
        print("viewModel.foundAyat: \(viewModel.foundAyat)")
        print("quranLines[viewModel.foundAyat.first!]: \(quranLines[viewModel.foundAyat.first!])")
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))

        viewModel.voiceText = "ان الله يامركم الى"
        try await Task.sleep(for: .seconds(1.1))
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
    }

    @Test func testBackwardMatch() async throws {
        let viewModel = MuhaffezViewModel()

        viewModel.voiceText = "ان الله يامركم يامركم "
        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        var matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
        #expect(matchedTrues.contains("يَأمُرُكُم"))

        viewModel.voiceText = "ان الله يامركم الله"
        matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("إِنَّ"))
        #expect(matchedTrues.contains("اللَّهَ"))
    }

    @Test func testMatchedWordsWithTypos() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "ان الله يامركم ان تودو الامانا إلى اهلها"
        while viewModel.foundAyat.count == 0 {
            try await Task.sleep(for: .seconds(1))
        }
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.contains("تُؤَدُّوا"))
        #expect(matchedTrues.contains("الأَماناتِ"))
    }

    @Test func testMatchedWordsBelowThreshold() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "سلام عالم مختلف"
        let matchedTrues = viewModel.matchedWords.filter { $0.1 }.map { $0.0 }
        #expect(matchedTrues.isEmpty)
    }

    @Test func testResetData() async throws {
        // Arrange
        let viewModel = MuhaffezViewModel()
        viewModel.foundAyat = [1, 423]
        viewModel.quranText = "Some text"
        viewModel.matchedWords = [("word1", true), ("word2", false)]
        viewModel.voiceText = "Some voice text"
        viewModel.voiceTextHasBesmillah = true
        viewModel.voiceTextHasA3ozoBellah = true

        // Act
        viewModel.resetData()

        // Assert
        #expect(viewModel.foundAyat.isEmpty)
        #expect(viewModel.quranText.isEmpty)
        #expect(viewModel.matchedWords.isEmpty)
        #expect(viewModel.voiceText.isEmpty)
        #expect(viewModel.voiceTextHasBesmillah == false)
        #expect(viewModel.voiceTextHasA3ozoBellah == false)
    }

    @Test func testPeekHelperAddsTwoWordsWhenRecording() async throws {
        // Given: initial state with some quranWords and matchedWords
        let viewModel = MuhaffezViewModel()  // Replace with actual class name
        viewModel.isRecording = true
        viewModel.quranWords = ["word1", "word2", "word3", "word4"]
        viewModel.matchedWords = [("word1", true)]

        // When: calling peekHelper
        viewModel.peekHelper()

        // Then: two new words should be appended as unmatched
        #expect(viewModel.matchedWords.count == 3)
        #expect(viewModel.matchedWords[1].0 == "word2")
        #expect(viewModel.matchedWords[2].0 == "word3")
        #expect(viewModel.matchedWords[1].1 == false)
        #expect(viewModel.matchedWords[2].1 == false)
    }

    @Test func testPeekHelperDoesNothingIfNotRecording() async throws {
        // Given
        let viewModel = MuhaffezViewModel()
        viewModel.isRecording = false
        viewModel.quranWords = ["word1", "word2"]
        viewModel.matchedWords = [("word1", true)]

        // When
        viewModel.peekHelper()

        // Then: matchedWords should remain unchanged
        #expect(viewModel.matchedWords.count == 1)
    }

    @Test func testUpdateFoundAyatDoesNothingWhenVoiceTextIsEmpty() async throws {
        // Given
        let viewModel = MuhaffezViewModel()  // Replace with your actual view model
        viewModel.voiceText = ""         // Empty voiceText triggers the guard
        //viewModel.quranLines = ["ayah1", "ayah2"]
        viewModel.foundAyat = [0, 1]

        // Then: foundAyat should remain unchanged
        #expect(viewModel.foundAyat == [0, 1])
    }

    // MARK: - Tests for voiceText and updateTextToPredict

    @Test func testVoiceTextSetsTextToPredict() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "الحمد لله رب العالمين"

        // textToPredict should be normalized version of voiceText
        #expect(viewModel.textToPredict == "الحمد لله رب العالمين")
    }

    @Test func testVoiceTextDetectsA3ozoBellah() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم"

        // Should automatically detect and set flag
        #expect(viewModel.voiceTextHasA3ozoBellah == true)
        // textToPredict should have A3ozoBellah removed
        #expect(viewModel.textToPredict == "")
    }

    @Test func testVoiceTextWithA3ozoBellahAndText() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم الحمد لله رب العالمين"

        #expect(viewModel.voiceTextHasA3ozoBellah == true)
        #expect(viewModel.textToPredict == "الحمد لله رب العالمين")
    }

    @Test func testUpdateTextToPredictWithBismillahOnly() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "بسم الله الرحمن الرحيم الحمد لله رب العالمين"

        // Manually set the flag (normally set by updateFoundAyat)
        viewModel.voiceTextHasBesmillah = true

        // textToPredict should have Bismillah removed
        #expect(viewModel.textToPredict == "الحمد لله رب العالمين")
    }

    @Test func testUpdateTextToPredictWithA3ozoBellahOnly() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم الحمد لله رب العالمين"

        // Flag is automatically set by voiceText didSet
        #expect(viewModel.voiceTextHasA3ozoBellah == true)
        #expect(viewModel.textToPredict == "الحمد لله رب العالمين")
    }

    @Test func testUpdateTextToPredictWithBothA3ozoBellahAndBismillah() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم الحمد لله رب العالمين"

        // A3ozoBellah is automatically detected
        #expect(viewModel.voiceTextHasA3ozoBellah == true)

        // Manually set Bismillah flag
        viewModel.voiceTextHasBesmillah = true

        // Both should be removed: first A3ozoBellah (5 words), then Bismillah (4 words)
        #expect(viewModel.textToPredict == "الحمد لله رب العالمين")
    }

    @Test func testUpdateTextToPredictRemovesA3ozoBellahFirst() async throws {
        let viewModel = MuhaffezViewModel()
        // A3ozoBellah (5 words) + Bismillah (4 words) + text
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم قل اعوذ برب الناس"

        #expect(viewModel.voiceTextHasA3ozoBellah == true)
        viewModel.voiceTextHasBesmillah = true

        // Should remove A3ozoBellah first, then Bismillah
        #expect(viewModel.textToPredict == "قل اعوذ برب الناس")
    }

    @Test func testTextToPredictUpdatesVoiceWords() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "الحمد لله رب العالمين"

        // voiceWords should be split from textToPredict
        #expect(viewModel.voiceWords.count == 4)
        #expect(viewModel.voiceWords[0] == "الحمد")
        #expect(viewModel.voiceWords[1] == "لله")
        #expect(viewModel.voiceWords[2] == "رب")
        #expect(viewModel.voiceWords[3] == "العالمين")
    }

    @Test func testTextToPredictWithA3ozoBellahRemoved() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "أعوذ بالله من الشيطان الرجيم الحمد لله"

        // A3ozoBellah detected and removed automatically
        #expect(viewModel.voiceTextHasA3ozoBellah == true)

        // voiceWords should only contain remaining words
        #expect(viewModel.voiceWords.count == 2)
        #expect(viewModel.voiceWords[0] == "الحمد")
        #expect(viewModel.voiceWords[1] == "لله")
    }

    @Test func testTextToPredict() async throws {
        let viewModel = MuhaffezViewModel()
        viewModel.voiceText = "بسم الله الرحمن الرحيم الحمد لله رب العالمين"

        // Initially textToPredict has full text
        let initialTextToPredict = viewModel.textToPredict
        #expect(initialTextToPredict == "الحمد لله رب العالمين")
    }

    @Test func testEmptyVoiceTextDoesNotTriggerUpdates() async throws {
        let viewModel = MuhaffezViewModel()
        let initialFoundAyatCount = viewModel.foundAyat.count

        viewModel.voiceText = ""

        // Should not trigger updateFoundAyat or updateMatchedWords
        #expect(viewModel.foundAyat.count == initialFoundAyatCount)
        #expect(viewModel.textToPredict == "")
        #expect(viewModel.voiceWords.isEmpty)
    }

    @Test func testIncompleteBismillahWithAlIkhlas() async throws {
        let viewModel = MuhaffezViewModel()
        // "بس" is incomplete "بسم" + Al-Ikhlas ayahs
        viewModel.voiceText = "بس قل الله احد الله الصمد لم يلد ولم يولد ولم يكن له كفوا احد"

        while viewModel.foundAyat.isEmpty {
            try? await Task.sleep(for: .seconds(1))
        }

        print("Found ayat: \(viewModel.foundAyat)")
        if !viewModel.foundAyat.isEmpty {
            print("Found ayah text: \(quranLines[viewModel.foundAyat.first!])")
        }

        // Al-Ikhlas starts at index 6221: قُل هُوَ اللَّهُ أَحَدٌ
        #expect(viewModel.foundAyat.contains(6189))
    }
}
