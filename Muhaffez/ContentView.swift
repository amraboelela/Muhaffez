//
//  ContentView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var recognizer = ArabicSpeechRecognizer()
    @State var viewModel = QuranViewModel()

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading) {
                        if viewModel.matchedWords.count == 0 && !viewModel.voiceText.isEmpty {
                            Text("...")
                                .environment(\.layoutDirection, .rightToLeft)
                        } else {
                            Text(viewModel.displayText)
                                .environment(\.layoutDirection, .rightToLeft)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                    }
                }
                .border(Color.gray)
                .padding()
                .onChange(of: recognizer.voiceText) { _, _ in
                    withAnimation {
                        proxy.scrollTo("BOTTOM", anchor: .bottom)
                    }
                }
            }
            Button(action: {
                if viewModel.isRecording {
                    recognizer.stopRecording()

                } else {
                    viewModel.resetData()
                    Task {
                        try? recognizer.startRecording()
                    }
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
