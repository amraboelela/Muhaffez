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

    var body: some Scene {
        WindowGroup {
            ContentView()
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

