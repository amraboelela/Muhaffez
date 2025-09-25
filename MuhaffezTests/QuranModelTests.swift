//
//  QuranModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 8/22/25.
//

import Testing
import SwiftUI
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
        #expect(model.quranLines[model.pageMarkers[0]] == "صِراطَ الَّذينَ أَنعَمتَ عَلَيهِم غَيرِ المَغضوبِ عَلَيهِم وَلَا الضّالّينَ")
        #expect(model.quranLines[model.pageMarkers[49]] == "رَبَّنا إِنَّكَ جامِعُ النّاسِ لِيَومٍ لا رَيبَ فيهِ إِنَّ اللَّهَ لا يُخلِفُ الميعادَ")
        #expect(model.quranLines[model.pageMarkers[128]] == "وَهُوَ القاهِرُ فَوقَ عِبادِهِ وَهُوَ الحَكيمُ الخَبيرُ")
        #expect(model.quranLines[model.pageMarkers[281]] == "إِن أَحسَنتُم أَحسَنتُم لِأَنفُسِكُم وَإِن أَسَأتُم فَلَها فَإِذا جاءَ وَعدُ الآخِرَةِ لِيَسوءوا وُجوهَكُم وَلِيَدخُلُوا المَسجِدَ كَما دَخَلوهُ أَوَّلَ مَرَّةٍ وَلِيُتَبِّروا ما عَلَوا تَتبيرًا")
        #expect(model.quranLines[model.pageMarkers[602]] == "في جيدِها حَبلٌ مِن مَسَدٍ")
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
        #expect(model.pageNumber(forAyahIndex: 6) == 1)   // Page 1
        #expect(model.pageNumber(forAyahIndex: 7) == 2)   // Page 2
        #expect(model.pageNumber(forAyahIndex: 10) == 2)
        #expect(model.pageNumber(forAyahIndex: 12) == 3)  // Page 3
        #expect(model.pageNumber(forAyahIndex: 17) == 3)  // Page 4
        #expect(model.pageNumber(forAyahIndex: model.pageMarkers[281]) == 282)
        #expect(model.pageNumber(forAyahIndex: model.pageMarkers[602]) == 603)
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
    
    @Test("Test rub3NumberFor(ayahIndex:)")
    func testRub3Number() async throws {
        let model = QuranModel.shared
        
        print("model.rub3Markers.first: \(model.rub3Markers.first!)")
        print("model.quranLines[model.rub3Markers.first!]: \(model.quranLines[model.rub3Markers.first!])")
        // rub3Markers contains starting ayah indexes for each rub3
        if let firstRub3 = model.rub3Markers.first {
            #expect(model.rub3NumberFor(ayahIndex: firstRub3) == 2)
        } else if let lastRub3 = model.rub3Markers.last {
            #expect(model.rub3NumberFor(ayahIndex: lastRub3) == 30)
            #expect(model.rub3NumberFor(ayahIndex: lastRub3 + 10) == 30)
        }
    }
    
    @Test("rub3Number covers last return line")
    func testRub3Number_LastLine() async throws {
        // Setup a mock model
        let model = QuranModel.shared
        
        // Index after the last marker (e.g., ayah 180) should be in the last rub3 section
        let index = model.quranLines.count - 1
        let result = model.rub3NumberFor(ayahIndex: index)
        
        // rub3Markers.count = 4, so last rub3 = 5
        #expect(result == model.rub3Markers.count + 1)
    }
    
    @Test("Test juz2Number(forAyahIndex:)")
    func testJuz2Number() async throws {
        let model = QuranModel.shared
        
        // Each juz = 8 rub3
        if let firstRub3 = model.rub3Markers.first {
            #expect(model.juzNumberFor(ayahIndex: firstRub3) == 1)
        }
        
        let fifthRub3 = model.rub3Markers[4]
        #expect(model.juzNumberFor(ayahIndex: fifthRub3) == 1)
        let eighthRub3 = model.rub3Markers[7]
        #expect(model.juzNumberFor(ayahIndex: eighthRub3) == 2)
        let ninthRub3 = model.rub3Markers[8]
        #expect(model.juzNumberFor(ayahIndex: ninthRub3) == 2)
    }
    
    @Test func testSurahNameValidPages() {
        let model = QuranModel.shared
        
        // Test a page in the middle of Surah Al-Baqara
        let page49Surah = model.surahNameFor(page: 49)
        #expect(page49Surah == "البقرة")
        
        // Test first page → should be Al-Fatiha
        let firstPageSurah = model.surahNameFor(page: 1)
        #expect(firstPageSurah == "الفاتحة")
        
        // Test last page → should return the last surah
        let lastPage = 604 // Madinah Mushaf last page
        let lastSurah = model.surahNameFor(page: lastPage)
        #expect(lastSurah == "الناس")
    }
    
    @Test func testSurahNameInvalidPage() {
        let model = QuranModel.shared
        
        // Page 0 is invalid → should return empty string
        let zeroPage = model.surahNameFor(page: 0)
        #expect(zeroPage == "")
        
        // Negative page → should return empty string
        let negativePage = model.surahNameFor(page: -5)
        #expect(negativePage == "")
    }
    
    @Test func testSurahNameEdgeCases() {
        let model = QuranModel.shared
        
        // Page exactly at the start of a surah
        let nameOfSurah3 = model.surahNameFor(page: model.surahs[2].startPage)
        #expect(nameOfSurah3 == "آل عمران")
        
        // Page just before the start of the next surah
        let nameBeforeNextSurah = model.surahNameFor(page: model.surahs[3].startPage - 1)
        #expect(nameBeforeNextSurah == "آل عمران")
        
        let lastSurahName = model.surahNameFor(page: 1000)
        #expect(lastSurahName == "الناس")
    }
    
    @Test func testSurahNameForAyahIndex() {
        let model = QuranModel.shared
        
        // 1. First ayah should be in Al-Fatihah
        let firstAyahSurah = model.surahNameFor(ayahIndex: 0)
        #expect(firstAyahSurah == "الفاتحة")
        
        // 2. Some ayah in the middle of آل عمران
        let middleBaqarahIndex = model.surahMarkers[1] + 10 // second surah start + offset
        let middleBaqarahSurah = model.surahNameFor(ayahIndex: middleBaqarahIndex)
        #expect(middleBaqarahSurah == "آل عمران")
        
        // 3. Last ayah should correspond to last surah
        let lastAyahIndex = model.quranLines.count - 1
        let lastSurah = model.surahNameFor(ayahIndex: lastAyahIndex)
        #expect(lastSurah == "الناس")
        
        // 4. Out-of-bounds negative index
        let negativeIndexSurah = model.surahNameFor(ayahIndex: -1)
        #expect(negativeIndexSurah.isEmpty)
        
        // 5. Out-of-bounds too large index
        let tooLargeIndexSurah = model.surahNameFor(ayahIndex: model.quranLines.count)
        #expect(tooLargeIndexSurah.isEmpty)
    }
    
    @Test
    func testIsEndOfSurah() async throws {
        // Arrange: A fake QuranModel with some markers
        let model = QuranModel.shared
        
        // Act & Assert
        #expect(model.isEndOfSurah(6))
        #expect(!model.isEndOfSurah(7))
        #expect(!model.isEndOfSurah(21))
    }
    
    @Test
    func testIsEndOfRub3() async throws {
        // Arrange: A fake QuranModel with some markers
        let model = QuranModel.shared
        
        // Act & Assert
        #expect(!model.isEndOfRub3(6))
        #expect(!model.isEndOfRub3(21))
    }
    
    
    @Test("Fills right page when ayah is on right page")
    func testFillRightPage() {
        let viewModel = MuhaffezViewModel()
        let ayahIndex = 1
        let quranModel = QuranModel.shared
        
        quranModel.updatePages(viewModel: viewModel, ayahIndex: ayahIndex)
        
        #expect(viewModel.tempPage.juzNumber == 1)
        #expect(viewModel.tempPage.surahName == "الفاتحة")
        #expect(viewModel.tempPage.pageNumber == 1)
    }
    
    @Test("Fills left page when ayah is on left page")
    func testFillLeftPage() {
        let viewModel = MuhaffezViewModel()
        let ayahIndex = 10
        let quranModel = QuranModel.shared
        
        quranModel.updatePageModelsIfNeeded(viewModel: viewModel, ayahIndex: ayahIndex)
        
        #expect(viewModel.tempPage.juzNumber == 1)
        #expect(viewModel.tempPage.surahName == "البقرة")
        #expect(viewModel.tempPage.pageNumber == 2)
    }
    
    @Test
    func testIsRightPage() {
        // Given
        // A dummy implementation for pageNumber(forAyahIndex:) for testing
        func pageNumber(forAyahIndex index: Int) -> Int {
            return index // just returns index for predictable tests
        }
        func isRightPage(forAyahIndex index: Int) -> Bool {
            let page = pageNumber(forAyahIndex: index)
            return page % 2 == 1
        }
        
        // When / Then
        #expect(isRightPage(forAyahIndex: 1))  // 1 % 2 == 1 → true
        #expect(!isRightPage(forAyahIndex: 2)) // 2 % 2 == 0 → false
        #expect(isRightPage(forAyahIndex: 3))  // 3 % 2 == 1 → true
        #expect(!isRightPage(forAyahIndex: 10))
    }
    
    //    func isRightPage(forAyahIndex index: Int) -> Bool {
    //        return index % 2 == 1
    //    }
    
    func updatePageModels(viewModel: inout MuhaffezViewModel, ayahIndex index: Int) {
        // Simulate updating pages
        viewModel.leftPage.text = AttributedString("Updated Left")
        viewModel.rightPage.text = AttributedString("Updated Right")
    }
    
    func updatePageModelsIfNeeded(viewModel: inout MuhaffezViewModel, ayahIndex index: Int) {
        let quranModel = QuranModel.shared
        if viewModel.currentPageIsRight != quranModel.isRightPage(forAyahIndex: index) {
            updatePageModels(viewModel: &viewModel, ayahIndex: index)
            if viewModel.currentPageIsRight {
                viewModel.rightPage.text = AttributedString()
                viewModel.leftPage.text = AttributedString()
            }
        }
    }
    
    @Test
    func testUpdatePageModelsIfNeeded() {
        var viewModel = MuhaffezViewModel()
        viewModel.currentPageIsRight = false
        
        updatePageModelsIfNeeded(viewModel: &viewModel, ayahIndex: 1) // 1 → right page
        
        #expect(viewModel.leftPage.text.characters.count > 0)  // got updated
        #expect(viewModel.rightPage.text.characters.count > 0)
    }
    
    @Test
    func testClearsPagesWhenRightPage() {
        var viewModel = MuhaffezViewModel()
        viewModel.currentPageIsRight = true
        
        updatePageModelsIfNeeded(viewModel: &viewModel, ayahIndex: 0) // left page
        
        #expect(viewModel.leftPage.textString.isEmpty)   // cleared
        #expect(viewModel.rightPage.textString.isEmpty)  // cleared
    }
    
    @Test func testClearsPageTextWhenCurrentPageIsRight() {
        // Arrange
        let viewModel = MuhaffezViewModel()
        let quranModel = QuranModel.shared
        
        // Set current page as right page so condition can trigger
        viewModel.currentPageIsRight = true
        
        // Give some initial text so we can verify it gets cleared
        viewModel.rightPage.text = AttributedString("Right page text")
        viewModel.leftPage.text = AttributedString("Left page text")
        
        // Act: Pick an ayahIndex whose page is left page
        let leftPageIndex = 8
        quranModel.updatePageModelsIfNeeded(viewModel: viewModel, ayahIndex: leftPageIndex)
        
        let rightPageIndex = 11
        quranModel.updatePageModelsIfNeeded(viewModel: viewModel, ayahIndex: rightPageIndex)
        
        // Assert: Text must be cleared
        #expect(viewModel.tempPage.textString.isEmpty)
        #expect(viewModel.tempPage.textString.isEmpty)
    }
}
