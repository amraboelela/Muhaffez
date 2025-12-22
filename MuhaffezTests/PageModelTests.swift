//
//  PageModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 12/22/25.
//

import Testing
import SwiftUI
@testable import Muhaffez

@MainActor
struct PageModelTests {

    @Test func testPageTypeEnumCases() {
        // Test that PageType enum has all expected cases
        let leftType: PageType = .left
        let rightType: PageType = .right
        let preLeftType: PageType = .preLeft

        #expect(leftType == .left)
        #expect(rightType == .right)
        #expect(preLeftType == .preLeft)
    }

    @Test func testPageModelDefaultPageType() {
        // Test that PageModel has default pageType of .right
        let pageModel = PageModel()

        #expect(pageModel.pageType == .right)
    }

    @Test func testPageModelWithCustomPageType() {
        // Test that PageModel can be initialized with custom pageType
        var leftPageModel = PageModel()
        leftPageModel.pageType = .left
        #expect(leftPageModel.pageType == .left)

        var rightPageModel = PageModel()
        rightPageModel.pageType = .right
        #expect(rightPageModel.pageType == .right)

        var preLeftPageModel = PageModel()
        preLeftPageModel.pageType = .preLeft
        #expect(preLeftPageModel.pageType == .preLeft)
    }

    @Test func testPageModelResetResetsPageType() {
        // Test that reset() resets pageType to default (.right)
        var pageModel = PageModel()
        pageModel.pageType = .left
        pageModel.juzNumber = 5
        pageModel.surahName = "البقرة"
        pageModel.pageNumber = 10
        pageModel.text = AttributedString("Test text")
        pageModel.isFirstPage = true

        #expect(pageModel.pageType == .left)

        // Call reset
        pageModel.reset()

        #expect(pageModel.pageType == .left)
        #expect(pageModel.juzNumber == 0)
        #expect(pageModel.surahName == "")
        #expect(pageModel.pageNumber == 0)
        #expect(pageModel.text == AttributedString())
        #expect(pageModel.isFirstPage == false)
    }

    @Test func testPageModelIsEmptyWithContent() {
        // Test isEmpty returns false when there is content
        var pageModel = PageModel()
        pageModel.text = AttributedString("Some text")

        #expect(!pageModel.isEmpty)
    }

    @Test func testPageModelIsEmptyWithoutContent() {
        // Test isEmpty returns true when there is no content
        let pageModel = PageModel()

        #expect(pageModel.isEmpty)
    }

    @Test func testPageModelTextString() {
        // Test textString property returns correct string
        var pageModel = PageModel()
        let testText = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"
        pageModel.text = AttributedString(testText)

        #expect(pageModel.textString == testText)
    }

    @Test func testPageModelWithAllProperties() {
        // Test PageModel with all properties set
        var pageModel = PageModel()
        pageModel.juzNumber = 15
        pageModel.surahName = "الكهف"
        pageModel.pageNumber = 293
        pageModel.text = AttributedString("Test content")
        pageModel.isFirstPage = false
        pageModel.pageType = .preLeft

        #expect(pageModel.juzNumber == 15)
        #expect(pageModel.surahName == "الكهف")
        #expect(pageModel.pageNumber == 293)
        #expect(pageModel.textString == "Test content")
        #expect(pageModel.isFirstPage == false)
        #expect(pageModel.pageType == .preLeft)
    }
}
