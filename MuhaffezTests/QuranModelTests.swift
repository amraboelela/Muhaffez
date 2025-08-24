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

    @Test func testSurahNameValidPages() {
        let model = QuranModel.shared

        // Test a page in the middle of Surah Al-Baqara
        let page49Surah = model.surahName(forPage: 49)
        #expect(page49Surah == "البقرة")

        // Test first page → should be Al-Fatiha
        let firstPageSurah = model.surahName(forPage: 1)
        #expect(firstPageSurah == "الفاتحة")

        // Test last page → should return the last surah
        let lastPage = 604 // Madinah Mushaf last page
        let lastSurah = model.surahName(forPage: lastPage)
        #expect(lastSurah == "الناس")
    }

    @Test func testSurahNameInvalidPage() {
        let model = QuranModel.shared

        // Page 0 is invalid → should return empty string
        let zeroPage = model.surahName(forPage: 0)
        #expect(zeroPage == "")

        // Negative page → should return empty string
        let negativePage = model.surahName(forPage: -5)
        #expect(negativePage == "")
    }

    @Test func testSurahNameEdgeCases() {
        let model = QuranModel.shared

        // Page exactly at the start of a surah
        let nameOfSurah3 = model.surahName(forPage: model.surahs[2].startPage)
        #expect(nameOfSurah3 == "آل عمران")

        // Page just before the start of the next surah
        let nameBeforeNextSurah = model.surahName(forPage: model.surahs[3].startPage - 1)
        #expect(nameBeforeNextSurah == "آل عمران")

        let lastSurahName = model.surahName(forPage: 1000)
        #expect(lastSurahName == "الناس")
    }

    @Test func testSurahNameForAyahIndex() {
        let model = QuranModel.shared

        // 1. First ayah should be in Al-Fatihah
        let firstAyahSurah = model.surahName(forAyahIndex: 0)
        #expect(firstAyahSurah == "الفاتحة")

        // 2. Some ayah in the middle of آل عمران
        let middleBaqarahIndex = model.surahMarkers[1] + 10 // second surah start + offset
        let middleBaqarahSurah = model.surahName(forAyahIndex: middleBaqarahIndex)
        #expect(middleBaqarahSurah == "آل عمران")

        // 3. Last ayah should correspond to last surah
        let lastAyahIndex = model.quranLines.count - 1
        let lastSurah = model.surahName(forAyahIndex: lastAyahIndex)
        #expect(lastSurah == "الناس")

        // 4. Out-of-bounds negative index
        let negativeIndexSurah = model.surahName(forAyahIndex: -1)
        #expect(negativeIndexSurah.isEmpty)

        // 5. Out-of-bounds too large index
        let tooLargeIndexSurah = model.surahName(forAyahIndex: model.quranLines.count)
        #expect(tooLargeIndexSurah.isEmpty)
    }
}
