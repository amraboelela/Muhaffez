//
//  MuhaffezView.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import SwiftUI

struct MuhaffezView: View {
    @StateObject var recognizer = ArabicSpeechRecognizer()
    @State var viewModel = MuhaffezViewModel()

    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                if viewModel.matchedWords.count == 0 && !viewModel.voiceText.isEmpty {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(2)
                        Spacer()
                    }
                } else {
                    Text(viewModel.displayText)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
            }
            .border(Color.gray)
            .padding()
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
            // testing progress view
//            viewModel.voiceText = "123"

            // Use this for testing
//            viewModel.foundAyat = [10]
//            viewModel.matchedWords = [("Verily", true), ("Allah", true), ("order", true), ("you", true), ("to", false), ("fullfill", true), ("the", false), ("deeds", true), ("of", false), ("your", false), ("parents", true), ("with", false), ("mercies", true), ("from", false), ("your", false), ("Lord", true), (".", false) ]
        }
    }
}

#Preview {
    MuhaffezView()
}
