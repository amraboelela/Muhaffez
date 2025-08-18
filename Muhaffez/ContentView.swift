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
    let synthesizer = AVSpeechSynthesizer() // speech synthesizer

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

            Button("Speak Arabic") {
                speakArabic(text: recognizer.recognizedText)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
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

    // Function to speak Arabic text
    func speakArabic(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA")
        utterance.rate = 0.5 // adjust speed (0.0 slow – 1.0 fast)
        synthesizer.speak(utterance)
    }
}


#Preview {
    ContentView()
}
