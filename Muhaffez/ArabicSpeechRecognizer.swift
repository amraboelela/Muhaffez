//
//  ArabicSpeechRecognizer.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 8/18/25.
//

import Speech
import AVFoundation

class ArabicSpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))!
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var shouldBeRecording = false
    // Text confirmed from completed recognition sessions, preserved across auto-restarts
    private var accumulatedText = ""

    @Published var voiceText: String = ""

    func startRecording() throws {
        print("startRecording")
        shouldBeRecording = true
        accumulatedText = ""
        try startRecognitionSession()
    }

    func stopRecording() {
        print("stopRecording")
        shouldBeRecording = false
        accumulatedText = ""
        audioEngine.stop()
        request?.endAudio()
    }

    // MARK: - Private

    private func startRecognitionSession() throws {
        print("startRecognitionSession, accumulatedText words: \(accumulatedText.split(separator: " ").count)")
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Prepare recognition request
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true

        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            Task { @MainActor in
                if let result {
                    let sessionText = result.bestTranscription.formattedString
                    self.voiceText = self.accumulatedText.isEmpty
                        ? sessionText
                        : self.accumulatedText + " " + sessionText
                }

                if error != nil || (result?.isFinal ?? false) {
                    if let error {
                        print("recognitionTask ended with error: \(error.localizedDescription)")
                    } else {
                        print("recognitionTask ended with isFinal")
                    }
                    // Save the final text from this session before stopping
                    if let result {
                        let sessionText = result.bestTranscription.formattedString
                        if !sessionText.isEmpty {
                            self.accumulatedText = self.accumulatedText.isEmpty
                                ? sessionText
                                : self.accumulatedText + " " + sessionText
                            print("accumulatedText words: \(self.accumulatedText.split(separator: " ").count)")
                        }
                    }
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                    self.request = nil
                    self.recognitionTask = nil

                    // Auto-restart if the user hasn't stopped recording
                    if self.shouldBeRecording {
                        print("Auto-restarting recognition session")
                        try? await Task.sleep(for: .seconds(0.3))
                        try? self.startRecognitionSession()
                    }
                }
            }
        }

        // Connect audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        print("audioEngine started")
    }
}
