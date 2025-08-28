//
//  PageModel.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/24/25.
//

import SwiftUI

struct PageModel {
  var juzNumber = 0
  var surahName = ""
  var pageNumber = 0
  var text = AttributedString()
  
  var textString: String {
    String(text.characters)
  }
  mutating func reset() {
    juzNumber = 0
    surahName = ""
    pageNumber = 0
    text = AttributedString()
  }
}
