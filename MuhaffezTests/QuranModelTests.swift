//
//  QuranModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/22/25.
//

import Testing
@testable import Muhaffez

@MainActor
struct QuranModelTests {

    @Test func testSingletonSharedInstance() {
        let instance1 = QuranModel.shared
        let instance2 = QuranModel.shared

        // Ensure both instances are identical (singleton)
        #expect(instance1 === instance2)
    }

    @Test func testQuranLinesNotEmpty() {
        let model = QuranModel.shared
        #expect(!model.quranLines.isEmpty, "Quran lines should not be empty")
    }

    @Test func testPageMarkersNotEmpty() {
        let model = QuranModel.shared
        #expect(!model.pageMarkers.isEmpty, "Page markers should not be empty")
    }

    @Test func testFirstLineContent() {
        let model = QuranModel.shared
        let firstLine = model.quranLines.first ?? ""

        // Make a simple sanity check: first line should contain Arabic text
        #expect(!firstLine.isEmpty)
        #expect(firstLine.range(of: "\\p{Arabic}", options: .regularExpression) != nil, "First line should contain Arabic characters")
    }

    @Test func testPageMarkersInRange() {
        let model = QuranModel.shared

        // All page markers should be valid indexes within quranLines
        for marker in model.pageMarkers {
            #expect(marker >= 0 && marker < model.quranLines.count)
        }
        #expect(model.pageMarkers.count == 603)
        #expect(model.quranLines[model.pageMarkers[0]] == "الم ذٰلِكَ الكِتابُ لا رَيبَ فيهِ هُدًى لِلمُتَّقينَ")
        #expect(model.quranLines[model.pageMarkers[49]] == "إِنَّ الَّذينَ كَفَروا لَن تُغنِيَ عَنهُم أَموالُهُم وَلا أَولادُهُم مِنَ اللَّهِ شَيئًا وَأُولٰئِكَ هُم وَقودُ النّارِ")
        #expect(model.quranLines[model.pageMarkers[127]] == "وَلَو جَعَلناهُ مَلَكًا لَجَعَلناهُ رَجُلًا وَلَلَبَسنا عَلَيهِم ما يَلبِسونَ")
        #expect(model.quranLines[model.pageMarkers[281]] == "عَسىٰ رَبُّكُم أَن يَرحَمَكُم وَإِن عُدتُم عُدنا وَجَعَلنا جَهَنَّمَ لِلكافِرينَ حَصيرًا")
        #expect(model.quranLines[model.pageMarkers[602]] == "قُل هُوَ اللَّهُ أَحَدٌ")
    }

    @Test func testPageMarkersSorted() {
        let model = QuranModel.shared
        let sortedMarkers = model.pageMarkers.sorted()
        #expect(model.pageMarkers == sortedMarkers, "Page markers should be sorted ascending")
    }

    @Test("Page number lookup works correctly")
    func testPageNumberForAyahIndex() async throws {
        // Create a dummy QuranModel with fake data
        let model = QuranModel.shared

        // Test ayah indices on different pages
        #expect(model.pageNumber(forAyahIndex: 0) == 1)   // Page 1
        #expect(model.pageNumber(forAyahIndex: 7) == 2)   // Page 2
        #expect(model.pageNumber(forAyahIndex: 12) == 3)  // Page 3
        #expect(model.pageNumber(forAyahIndex: 17) == 3)  // Page 4
        #expect(model.pageNumber(forAyahIndex: model.pageMarkers[281]) == 283)
        #expect(model.pageNumber(forAyahIndex: model.pageMarkers[602]) == 604)
    }

    @Test("Test pageNumber(forAyahIndex:)")
    func testPageNumber() async throws {
        let model = QuranModel.shared

        // Suppose pageMarkers were set correctly from your file
        #expect(model.pageNumber(forAyahIndex: 0) == 1)   // First ayah should be on page 1

        if let lastAyahIndex = model.quranLines.indices.last {
            #expect(model.pageNumber(forAyahIndex: lastAyahIndex) == model.pageMarkers.count + 1)
        }
    }

    @Test("Test rub3Number(forAyahIndex:)")
    func testRub3Number() async throws {
        let model = QuranModel.shared

        print("model.rub3Markers.first: \(model.rub3Markers.first!)")
        print("model.quranLines[model.rub3Markers.first!]: \(model.quranLines[model.rub3Markers.first!])")
        // rub3Markers contains starting ayah indexes for each rub3
        if let firstRub3 = model.rub3Markers.first {
            #expect(model.rub3Number(forAyahIndex: firstRub3) == 2)
        } else if let lastRub3 = model.rub3Markers.last {
            #expect(model.rub3Number(forAyahIndex: lastRub3) == 30)
            #expect(model.rub3Number(forAyahIndex: lastRub3 + 10) == 30)
        }
    }

    @Test("rub3Number covers last return line")
    func testRub3Number_LastLine() async throws {
        // Setup a mock model
        let model = QuranModel.shared

        // Index after the last marker (e.g., ayah 180) should be in the last rub3 section
        let index = model.quranLines.count - 1
        let result = model.rub3Number(forAyahIndex: index)

        // rub3Markers.count = 4, so last rub3 = 5
        #expect(result == model.rub3Markers.count + 1)
    }

    @Test("Test juz2Number(forAyahIndex:)")
    func testJuz2Number() async throws {
        let model = QuranModel.shared

        // Each juz = 8 rub3
        if let firstRub3 = model.rub3Markers.first {
            #expect(model.juz2Number(forAyahIndex: firstRub3) == 1)
        }

        let fifthRub3 = model.rub3Markers[4]
        #expect(model.juz2Number(forAyahIndex: fifthRub3) == 1)
        let eighthRub3 = model.rub3Markers[7]
        #expect(model.juz2Number(forAyahIndex: eighthRub3) == 2)
        let ninthRub3 = model.rub3Markers[8]
        #expect(model.juz2Number(forAyahIndex: ninthRub3) == 2)
    }

}
