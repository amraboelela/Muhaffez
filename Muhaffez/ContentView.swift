//
//  ContentView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var recognizer = ArabicSpeechRecognizer()
    @StateObject var viewModel = QuranViewModel()

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(AttributedString.coloredFromMatched(viewModel.matchedText))
                    .padding()
            }
            .frame(height: 500) // adjust height as needed
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
                viewModel.speakArabic(text: viewModel.recognizedText)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .onChange(of: recognizer.recognizedText) { _, newValue in
            print("#quran newValue: \(newValue)")
            viewModel.updateRecognizedText(newValue)
        }
        .onAppear {
            // Use this for testing
//            viewModel.matchedText = [("Verily", true), ("Allah", true), ("order", true), ("you", true), ("to", false), ("fullfill", true), ("the", false), ("deeds", true), ("of", false), ("your", false), ("parents", true), ("with", false), ("mercies", true), ("from", false), ("your", false), ("Lord", true), (".", false) ]
        }
    }
}

#Preview {
    ContentView()
}
