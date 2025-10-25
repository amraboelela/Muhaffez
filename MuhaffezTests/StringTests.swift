//
//  StringTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/19/25.
//

import Testing
@testable import Muhaffez

struct StringTests {
    
    @Test func testRemovingTashkeel() async throws {
        let text = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
        let expected = "بسم الله الرحمن الرحيم"
        print("text.removingTashkeel: \(text.removingTashkeel)")
        #expect(text.removingTashkeel == expected)
    }
    
    @Test func testNormalizedArabic_keepsTextIfNoPrefix() {
        // Arrange
        let original = "الحمد لله رب العالمين"
        let expected = original
        
        // Act
        let normalized = original.normalizedArabic
        
        // Assert
        #expect(normalized == expected)
    }
    
    @Test func testNormalizedArabic_normalizesHamzaVariants() {
        // Arrange
        let original = "أدخل إلى المدرسة"
        let expected = "ادخل الى المدرسة"
        
        // Act
        let normalized = original.normalizedArabic
        
        // Assert
        #expect(normalized == expected)
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
    
    @Test func testRemoveBasmallah() async throws {
        // Test with Bismillah followed by text
        let text1 = "بسم الله الرحمن الرحيم الحمد لله رب العالمين"
        let result1 = text1.removeBasmallah
        #expect(result1 == "الحمد لله رب العالمين")

        // Test with exact Bismillah (should return empty string)
        let text2 = "بسم الله الرحمن الرحيم"
        let result2 = text2.removeBasmallah
        #expect(result2 == "")

        let text3 = "بسم الله الرحمن"
        let result3 = text3.removeBasmallah
        #expect(result3 == "")

        // Test with text that doesn't start with Bismillah
        let text4 = "الحمد لله رب العالمين"
        let result4 = text4.removeBasmallah
        #expect(result4 == text4) // Should return unchanged

        // Test with incomplete Bismillah (missing "الرحمن")
        let text5 = "بسم الله الرحيم الحمد لله رب العالمين"
        let result5 = text5.removeBasmallah
        #expect(result5 == "الحمد لله رب العالمين")

        // Test with incomplete Bismillah (missing "الرحمن") - only Bismillah
        let text6 = "بسم الله الرحيم"
        let result6 = text6.removeBasmallah
        #expect(result6 == "")

        // Test with incomplete Bismillah (missing "الرحيم" - first 3 words)
        let text7 = "بسم الله الرحمن الحمد لله رب العالمين"
        let result7 = text7.removeBasmallah
        #expect(result7 == "الحمد لله رب العالمين")

        // Test with incomplete Bismillah (only first 3 words)
        let text8 = "بسم الله الرحمن"
        let result8 = text8.removeBasmallah
        #expect(result8 == "")
    }
    
    @Test func testRemoveA3ozoBellah() async throws {
        // Test with A3ozoBellah followed by text
        let text1 = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم"
        let result1 = text1.removeA3ozoBellah
        #expect(result1 == "بسم الله الرحمن الرحيم")
        
        // Test with exact A3ozoBellah (should return empty string)
        let text2 = "أعوذ بالله من الشيطان الرجيم"
        let result2 = text2.removeA3ozoBellah
        #expect(result2 == "")
        
        // Test with less than 6 words (should return original)
        let text3 = "أعوذ بالله من الشيطان"
        let result3 = text3.removeA3ozoBellah
        #expect(result3 == text3)
        
        // Test with A3ozoBellah + Bismillah + Quran text
        let text4 = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم الحمد لله رب العالمين"
        let result4 = text4.removeA3ozoBellah
        #expect(result4 == "بسم الله الرحمن الرحيم الحمد لله رب العالمين")
    }
    
    @Test func testHasA3ozoBellah() async throws {
        // Test with exact A3ozoBellah
        let text1 = "أعوذ بالله من الشيطان الرجيم"
        #expect(text1.hasA3ozoBellah == true)
        
        // Test with A3ozoBellah followed by text
        let text2 = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم"
        #expect(text2.hasA3ozoBellah == true)
        
        // Test with A3ozoBellah + Bismillah + Quran
        let text3 = "أعوذ بالله من الشيطان الرجيم بسم الله الرحمن الرحيم قل اعوذ برب الناس"
        #expect(text3.hasA3ozoBellah == true)
        
        // Test with text that doesn't have A3ozoBellah
        let text4 = "بسم الله الرحمن الرحيم"
        #expect(text4.hasA3ozoBellah == false)
        
        // Test with partial A3ozoBellah (less than 5 words)
        let text5 = "أعوذ بالله من الشيطان"
        #expect(text5.hasA3ozoBellah == false)
        
        // Test with similar but different text
        let text6 = "الحمد لله رب العالمين"
        #expect(text6.hasA3ozoBellah == false)
        
        // Test with slightly different A3ozoBellah (should still match with fuzzy matching)
        let text7 = "اعوذ بالله من الشيطا الرجيم"
        #expect(text7.hasA3ozoBellah == true)
        
        // Test empty string
        let text8 = ""
        #expect(text8.hasA3ozoBellah == false)
    }
}
