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

    private init() {
        var lines = [String]()
        var markers = [Int]()

        if let path = Bundle.main.path(forResource: "quran-simple-min", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                let fileLines = content.components(separatedBy: .newlines)

                var ayaCount = 0
                for line in fileLines {
                    if line.isEmpty {
                        markers.append(ayaCount)
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
        self.pageMarkers = markers
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
}
