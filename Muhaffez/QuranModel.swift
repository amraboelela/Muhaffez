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
}
