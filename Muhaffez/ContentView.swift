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
            Text(viewModel.matchedText)
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
                viewModel.speakArabic(text: viewModel.recognizedText)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .onChange(of: recognizer.recognizedText) { _, newValue in
            viewModel.updateRecognizedText(newValue)
        }
    }
}

#Preview {
    ContentView()
}
