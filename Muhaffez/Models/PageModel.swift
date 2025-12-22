//
//  PageModel.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/24/25.
//

import SwiftUI

enum PageType {
    case left
    case right
    case preLeft
}

struct PageModel {
    var juzNumber = 0
    var surahName = ""
    var pageNumber = 0
    var text = AttributedString()
    var isFirstPage = false
    var pageType: PageType = .right

    init(isLeft: Bool = false) {
        pageType = isLeft ? .left : .right
    }

    var textString: String {
        String(text.characters)
    }

    var isEmpty: Bool {
        textString.isEmpty
    }

    mutating func reset() {
        juzNumber = 0
        surahName = ""
        pageNumber = 0
        text = AttributedString()
        isFirstPage = false
        if pageType == .preLeft {
            pageType = .left
        }
    }
}
