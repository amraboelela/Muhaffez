//
//  StringExtensionTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/19/25.
//

import Testing
@testable import Muhaffez

struct StringExtensionTests {

    @Test func testRemovingTashkeel() async throws {
        let text = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
        let expected = "بسم الله الرحمٰن الرحيم"
        print("text.removingTashkeel: \(text.removingTashkeel)")
        #expect(text.removingTashkeel == expected)
    }

    @Test func testNormalizedArabicHamzaVariants() async throws {
        let text = "إسلام أمان آخرة مؤمن رئيس"
        let normalized = text.normalizedArabic
        // After normalization: إ -> ا, أ -> ا, آ -> ا, ؤ -> و, ئ -> ي
        print("normalized: \(normalized)")
        #expect(normalized.contains("اسلام"))
        #expect(normalized.contains("امان"))
        #expect(normalized.contains("اخرة"))
        #expect(normalized.contains("مومن"))
        #expect(normalized.contains("رييس"))
    }

    @Test func testFindIn() async throws {
        let lines = [
            "قال إنه من سليمان",
            "وإنه بسم الله الرحمن الرحيم",
            "ألا تعلوا علي وأتوني مسلمين"
        ]

        let search1 = "انه من سليمان"
        let found1 = search1.findIn(lines: lines)
        #expect(found1 == "قال إنه من سليمان")

        let search2 = "بسم الله"
        let found2 = search2.findIn(lines: lines)
        #expect(found2 == "وإنه بسم الله الرحمن الرحيم")

        let search3 = "غير موجود"
        let found3 = search3.findIn(lines: lines)
        #expect(found3 == nil)
    }

    @Test func testFindLineStartingIn() async throws {
        let lines = [
            "ان الله يأمركم أن تؤدوا الأمانات",
            "وإذا حكمتم بين الناس أن تحكموا بالعدل"
        ]

        let search = "ان الله يأمركم"
        if let result = search.findLineStartingIn(lines: lines) {
            #expect(result.index == 0)
            #expect(result.line == "ان الله يأمركم أن تؤدوا الأمانات")
        } else {
            #expect(Bool(false)) // Fail if not found
        }
    }

    @Test func testLevenshteinDistance() async throws {
        #expect("kitten".levenshteinDistance(to: "sitting") == 3)
        #expect("flaw".levenshteinDistance(to: "lawn") == 2)
        #expect("test".levenshteinDistance(to: "test") == 0)
    }

    @Test func testSimilarity() async throws {
        let sim1 = "kitten".similarity(to: "sitting")
        let sim2 = "flaw".similarity(to: "lawn")
        let sim3 = "identical".similarity(to: "identical")

        print("sim1: \(sim1)")
        print("sim2: \(sim2)")
        print("sim3: \(sim3)")
        #expect(sim1 > 0.5 && sim1 < 1.0)
        #expect(sim2 >= 0.5 && sim2 < 1.0)
        #expect(sim3 == 1.0)
    }
}

