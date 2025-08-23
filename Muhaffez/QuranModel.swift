//
//  QuranModel.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/22/25.
//

import Foundation

@MainActor
class QuranModel {
    static let shared = QuranModel()

    let quranLines: [String]
    let pageMarkers: [Int]
    let rub3Markers: [Int]

    private init() {
        var lines = [String]()
        var pageMarkers = [Int]()
        var rub3Markers = [Int]()

        if let path = Bundle.main.path(forResource: "quran-simple-min", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                let fileLines = content.components(separatedBy: .newlines)

                var ayaCount = 0
                for line in fileLines {
                    if line.isEmpty {
                        pageMarkers.append(ayaCount)
                    } else if line == "*" {
                        rub3Markers.append(ayaCount)
                    } else {
                        lines.append(line)
                        ayaCount += 1
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
    }

    /// Returns the page number for the given ayah index
    func pageNumber(forAyahIndex index: Int) -> Int? {
        guard !pageMarkers.isEmpty, index >= 0, index < quranLines.count else {
            return nil
        }

        // Find the first marker greater than the index → that's the next page start
        for (pageIndex, marker) in pageMarkers.enumerated() {
            if index < marker {
                return pageIndex + 1 // Pages are usually 1-based
            }
        }

        // If it's after the last marker, it's on the last page
        return pageMarkers.count + 1
    }

    /// Returns the rub3 number for the given ayah index
    func rub3Number(forAyahIndex index: Int) -> Int {
        guard !rub3Markers.isEmpty, index >= 0, index < quranLines.count else {
            return 1
        }

        // Find the first rub3 marker greater than the index → that's the next rub3 start
        for (rub3Index, marker) in rub3Markers.enumerated() {
            if index < marker {
                return rub3Index + 1 // Rub3 sections are usually 1-based
            }
        }

        // If it's after the last marker, it's in the last rub3 section
        return rub3Markers.count + 1
    }

    /// Returns the juz number for the given ayah index
    func juz2Number(forAyahIndex index: Int) -> Int {
        let rub3Num = rub3Number(forAyahIndex: index)
        // Each juz = 4 rub3 → use ceil to handle partials correctly
        return Int(ceil(Double(rub3Num) / 8.0))
    }
}
