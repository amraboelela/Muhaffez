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
                Text(AttributedString.coloredFromMatched(viewModel.matchedWords))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 500) // adjust height as needed
            .border(Color.gray)
            .padding()
            HStack(spacing: 30) {
                Button(action: {
                    if viewModel.isRecording {
                        recognizer.stopRecording()
                    } else {
                        try? recognizer.startRecording()
                    }
                    viewModel.isRecording.toggle()
                }) {
                    Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 40))
                        .foregroundColor(viewModel.isRecording ? .red : .blue)
                        .padding()
                        .background(Circle().fill(Color(.systemGray6)))
                        .shadow(radius: 4)
                }
                Button(action: {
                    recognizer.stopRecording()
                    Task {
                        viewModel.isRecording = false
                        viewModel.voiceText = ""
                        viewModel.matchedWords = []
                    }
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                        .padding()
                        .background(Circle().fill(Color(.systemGray6)))
                        .shadow(radius: 4)
                }
            }
            //            Button("Speak Arabic") {
            //                viewModel.speakArabic(text: viewModel.voiceText)
            //            }
            //            .padding()
            //            .background(Color.blue)
            //            .foregroundColor(.white)
            //            .cornerRadius(8)
        }
        .onChange(of: recognizer.voiceText) { _, newValue in
            print("#quran newValue: \(newValue)")
            viewModel.voiceText = newValue //updatevoiceText(newValue)
        }
        .onAppear {
            // Use this for testing
//            viewModel.matchedWords = [("Verily", true), ("Allah", true), ("order", true), ("you", true), ("to", false), ("fullfill", true), ("the", false), ("deeds", true), ("of", false), ("your", false), ("parents", true), ("with", false), ("mercies", true), ("from", false), ("your", false), ("Lord", true), (".", false) ]
        }
    }
}

#Preview {
    ContentView()
}
