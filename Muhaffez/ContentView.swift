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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading) {
                        if viewModel.matchedWords.count == 0 && !viewModel.voiceText.isEmpty {
                            Text("...")
                                .environment(\.layoutDirection, .rightToLeft)
                        } else {
                            Text(AttributedString.coloredFromMatched(viewModel.matchedWords))
                                .environment(\.layoutDirection, .rightToLeft)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                    }
                }
                .frame(height: 500) // adjust height as needed
                .border(Color.gray)
                .padding()
                .onChange(of: recognizer.voiceText) { _, _ in
                    withAnimation {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
            }
            //HStack(spacing: 30) {
            Button(action: {
                if viewModel.isRecording {
                    recognizer.stopRecording()
                    Task {
                        viewModel.resetData()
                    }
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
            //                Button(action: {
            //                    recognizer.stopRecording()
            //                    Task {
            //                        viewModel.isRecording = false
            //                        viewModel.voiceText = ""
            //                        viewModel.matchedWords = []
            //                    }
            //                }) {
            //                    Image(systemName: "arrow.clockwise.circle.fill")
            //                        .font(.system(size: 40))
            //                        .foregroundColor(.red)
            //                        .padding()
            //                        .background(Circle().fill(Color(.systemGray6)))
            //                        .shadow(radius: 4)
            //                }
            //}
        }
        .onChange(of: recognizer.voiceText) { _, newValue in
            print("#quran newValue: \(newValue)")
            viewModel.voiceText = newValue
        }
        .onAppear {
            // Use this for testing
            //                        viewModel.matchedWords = [("Verily", true), ("Allah", true), ("order", true), ("you", true), ("to", false), ("fullfill", true), ("the", false), ("deeds", true), ("of", false), ("your", false), ("parents", true), ("with", false), ("mercies", true), ("from", false), ("your", false), ("Lord", true), (".", false) ]
        }
    }
}

#Preview {
    ContentView()
}
