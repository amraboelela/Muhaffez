//
//  ContentView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import SwiftUI
import Speech
import AVFoundation

struct ContentView: View {
    @StateObject var recognizer = ArabicSpeechRecognizer()

    var body: some View {
        VStack(spacing: 20) {
            Text(recognizer.recognizedText)
                .padding()
                .border(Color.gray)

            HStack {
                Button("Start") {
                    try? recognizer.startRecording()
                }
                Button("Stop") {
                    recognizer.stopRecording()
                }
            }
        }
        .padding()
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

#Preview {
    ContentView()
}
