//
//  QuranModel.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/22/25.
//

import SwiftUI

@MainActor
class QuranModel {
  static let shared = QuranModel()
  
  let quranLines: [String]
  let pageMarkers: [Int]
  let rub3Markers: [Int]
  let surahMarkers: [Int]
  let surahs: [(startPage: Int, name: String)] = [
    (1, "الفاتحة"),
    (2, "البقرة"),
    (50, "آل عمران"),
    (77, "النساء"),
    (106, "المائدة"),
    (128, "الأنعام"),
    (151, "الأعراف"),
    (177, "الأنفال"),
    (187, "التوبة"),
    (208, "يونس"),
    (221, "هود"),
    (235, "يوسف"),
    (249, "الرعد"),
    (255, "إبراهيم"),
    (262, "الحجر"),
    (267, "النحل"),
    (282, "الإسراء"),
    (293, "الكهف"),
    (305, "مريم"),
    (312, "طه"),
    (322, "الأنبياء"),
    (332, "الحج"),
    (342, "المؤمنون"),
    (350, "النور"),
    (359, "الفرقان"),
    (367, "الشعراء"),
    (377, "النمل"),
    (385, "القصص"),
    (396, "العنكبوت"),
    (404, "الروم"),
    (411, "لقمان"),
    (415, "السجدة"),
    (418, "الأحزاب"),
    (428, "سبأ"),
    (434, "فاطر"),
    (440, "يس"),
    (446, "الصافات"),
    (453, "ص"),
    (458, "الزمر"),
    (467, "غافر"),
    (477, "فصلت"),
    (483, "الشورى"),
    (489, "الزخرف"),
    (496, "الدخان"),
    (499, "الجاثية"),
    (502, "الأحقاف"),
    (507, "محمد"),
    (511, "الفتح"),
    (515, "الحجرات"),
    (518, "ق"),
    (520, "الذاريات"),
    (523, "الطور"),
    (526, "النجم"),
    (528, "القمر"),
    (531, "الرحمن"),
    (534, "الواقعة"),
    (537, "الحديد"),
    (542, "المجادلة"),
    (545, "الحشر"),
    (549, "الممتحنة"),
    (551, "الصف"),
    (553, "الجمعة"),
    (554, "المنافقون"),
    (556, "التغابن"),
    (558, "الطلاق"),
    (560, "التحريم"),
    (562, "الملك"),
    (564, "القلم"),
    (566, "الحاقة"),
    (568, "المعارج"),
    (570, "نوح"),
    (572, "الجن"),
    (574, "المزمل"),
    (575, "المدثر"),
    (577, "القيامة"),
    (578, "الإنسان"),
    (580, "المرسلات"),
    (582, "النبأ"),
    (583, "النازعات"),
    (585, "عبس"),
    (586, "التكوير"),
    (587, "الانفطار"),
    (587, "المطففين"),
    (589, "الانشقاق"),
    (590, "البروج"),
    (591, "الطارق"),
    (591, "الأعلى"),
    (592, "الغاشية"),
    (593, "الفجر"),
    (594, "البلد"),
    (595, "الشمس"),
    (595, "الليل"),
    (596, "الضحى"),
    (596, "الشرح"),
    (597, "التين"),
    (597, "العلق"),
    (598, "القدر"),
    (598, "البينة"),
    (599, "الزلزلة"),
    (599, "العاديات"),
    (600, "القارعة"),
    (600, "التكاثر"),
    (601, "العصر"),
    (601, "الهمزة"),
    (601, "الفيل"),
    (602, "قريش"),
    (602, "الماعون"),
    (602, "الكوثر"),
    (603, "الكافرون"),
    (603, "النصر"),
    (603, "المسد"),
    (604, "الإخلاص"),
    (604, "الفلق"),
    (604, "الناس")
  ]
  
  private init() {
    var lines = [String]()
    var pageMarkers = [Int]()
    var rub3Markers = [Int]()
    var surahMarkers = [Int]()
    
    if let path = Bundle.main.path(forResource: "quran-simple-min", ofType: "txt") {
      do {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let fileLines = content.components(separatedBy: .newlines)
        
        for line in fileLines {
          if line.isEmpty {
            pageMarkers.append(lines.count - 1)
          } else if line == "*" {
            rub3Markers.append(lines.count - 1)
          } else if line == "-" {
            surahMarkers.append(lines.count - 1)
          } else {
            lines.append(line)
          }
        }
      } catch {
        print("❌ Error reading file:", error)
      }
    } else {
      print("❌ File not found in bundle")
    }
    
    self.quranLines = lines
    self.pageMarkers = pageMarkers
    self.rub3Markers = rub3Markers
    self.surahMarkers = surahMarkers
  }
  
  /// Returns the page number for the given ayah index
  func pageNumber(forAyahIndex index: Int) -> Int {
    guard !pageMarkers.isEmpty, index >= 0, index < quranLines.count else {
      return 0
    }
    
    // Find the first marker greater than the index → that's the next page start
    for (pageIndex, marker) in pageMarkers.enumerated() {
      if index <= marker {
        return pageIndex + 1 // Pages are usually 1-based
      }
    }
    
    // If it's after the last marker, it's on the last page
    return pageMarkers.count + 1
  }
  
  /// Returns the rub3 number for the given ayah index
  func rub3NumberFor(ayahIndex: Int) -> Int {
    guard !rub3Markers.isEmpty, ayahIndex >= 0, ayahIndex < quranLines.count else {
      return 0
    }
    
    // Find the first rub3 marker greater than the index → that's the next rub3 start
    for (rub3Index, marker) in rub3Markers.enumerated() {
      if ayahIndex < marker {
        return rub3Index + 1 // Rub3 sections are usually 1-based
      }
    }
    
    // If it's after the last marker, it's in the last rub3 section
    return rub3Markers.count + 1
  }
  
  /// Returns the juz number for the given ayah index
  func juzNumberFor(ayahIndex: Int) -> Int {
    let rub3Num = rub3NumberFor(ayahIndex: ayahIndex)
    // Each juz = 4 rub3 → use ceil to handle partials correctly
    return Int(ceil(Double(rub3Num) / 8.0))
  }
  
  func surahNameFor(page: Int) -> String {
    guard page >= 1 else { return "" }
    for i in (0..<surahs.count).reversed() {
      if page >= surahs[i].startPage {
        return surahs[i].name
      }
    }
    return ""
  }
  
  /// Returns the surah name for a given ayah index in quranLines
  func surahNameFor(ayahIndex: Int) -> String {
    guard !surahMarkers.isEmpty, ayahIndex >= 0, ayahIndex < quranLines.count else {
      return ""
    }
    
    // Find the last marker that is <= ayahIndex
    for i in (0..<surahMarkers.count).reversed() {
      if ayahIndex >= surahMarkers[i] {
        // Return the corresponding surah name from surahs array
        // Note: assuming surahMarkers and surahs are in sync
        return surahs[i+1].name
      }
    }
    
    return surahs[0].name
  }
  
  func isRightPage(forAyahIndex index: Int) -> Bool {
    let page = pageNumber(forAyahIndex: index)
    return page % 2 == 1
  }
  
  func updatePages(viewModel: MuhaffezViewModel, ayahIndex index: Int) {
    if isRightPage(forAyahIndex: index) {
      viewModel.tempRightPage.juzNumber = juzNumberFor(ayahIndex: index)
      viewModel.tempRightPage.surahName = surahNameFor(ayahIndex: index)
      viewModel.tempRightPage.pageNumber = pageNumber(forAyahIndex: index)
    } else {
      viewModel.tempLeftPage.juzNumber = juzNumberFor(ayahIndex: index)
      viewModel.tempLeftPage.surahName = surahNameFor(ayahIndex: index)
      viewModel.tempLeftPage.pageNumber = pageNumber(forAyahIndex: index)
    }
    viewModel.currentPageIsRight = isRightPage(forAyahIndex: index)
  }
  
  func updatePageModelsIfNeeded(viewModel: MuhaffezViewModel, ayahIndex index: Int) {
    if viewModel.currentPageIsRight != isRightPage(forAyahIndex: index) {
      updatePages(viewModel: viewModel, ayahIndex: index)
      if viewModel.currentPageIsRight {
        viewModel.tempRightPage.text = AttributedString()
        viewModel.tempLeftPage.text = AttributedString()
      }
    }
  }
  
  /// Helper: true if current ayah index is at the end of a rub3
  func isEndOfRub3(_ ayahIndex: Int) -> Bool {
    return rub3Markers.contains(ayahIndex)
  }
  
  func isEndOfSurah(_ ayahIndex: Int) -> Bool {
    return surahMarkers.contains(ayahIndex)
  }
}
