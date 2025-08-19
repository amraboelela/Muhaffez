//
//  MuhaffezApp.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import SwiftUI
import Speech
import AVFoundation

@main
struct MuhaffezApp: App {
    // Load file into memory at app launch
    let quranLines: [String] = {
        if let path = Bundle.main.path(forResource: "quran-simple-min", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                // Split into lines
                return content.components(separatedBy: .newlines)
                    .filter { !$0.isEmpty } // remove empty lines
            } catch {
                print("❌ Error reading file:", error)
                return []
            }
        } else {
            print("❌ File not found in bundle")
            return []
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(quranLines: quranLines)
                .onAppear {
                    SFSpeechRecognizer.requestAuthorization { status in
                        switch status {
                        case .authorized:
                            print("Speech recognition authorized")
                        default:
                            print("Speech recognition not authorized")
                        }
                    }
                }
        }
    }
}

