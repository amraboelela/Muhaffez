//
//  AyaFinderMLModel.swift
//  Muhaffez
//
//  Created by Amr Aboelela on 10/14/25.
//

import Foundation
import CoreML

class AyaFinderMLModel {
    private var model: MLModel?
    private var wordToIdx: [String: Int] = [:]
    private var idxToWord: [Int: String] = [:]
    private let maxLength = 50

    // Special tokens
    private var padToken: Int = 0      // <pad>
    private var bosToken: Int = 1      // <s>
    private var eosToken: Int = 2      // </s>
    private var readerToken: Int = 3   // القاريء:
    private var ayahToken: Int = 4     // الاية:

    init() {
        loadModel()
        loadVocabulary()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            model = try QuranSeq2Seq(configuration: config).model
            print("QuranSeq2Seq model loaded successfully")
        } catch {
            print("Error loading QuranSeq2Seq model: \(error)")
        }
    }

    private func loadVocabulary() {
        guard let url = Bundle.main.url(forResource: "vocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let vocabArray = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            print("Error loading vocabulary")
            return
        }

        // Build word-to-index and index-to-word mappings from array
        for (index, word) in vocabArray.enumerated() {
            wordToIdx[word] = index
            idxToWord[index] = word
        }

        // Get special token indices
        padToken = wordToIdx["<pad>"] ?? 0
        bosToken = wordToIdx["<s>"] ?? 1
        eosToken = wordToIdx["</s>"] ?? 2
        readerToken = wordToIdx["القاريء:"] ?? 3
        ayahToken = wordToIdx["الاية:"] ?? 4

        print("Vocabulary loaded: \(wordToIdx.count) tokens")
        print("Special tokens - PAD: \(padToken), BOS: \(bosToken), EOS: \(eosToken), Reader: \(readerToken), Ayah: \(ayahToken)")
    }

    func predict(text: String) -> String? {
        guard let model = model else {
            print("Model not loaded")
            return nil
        }

        // Normalize the input text
        let normalizedText = text.normalizedArabic

        // Split into words
        let inputWords = normalizedText.split(separator: " ").map { String($0) }

        guard !inputWords.isEmpty else {
            print("No input words after normalization")
            return nil
        }

        print("Input words: \(inputWords)")

        // Build sequence: <s> القاريء: [input_words] الاية:
        var sequenceTokens = [bosToken, readerToken]

        // Add input word tokens (limit to first 6 words to leave room for output)
        let maxInputWords = min(inputWords.count, 6)
        for i in 0..<maxInputWords {
            let word = inputWords[i]
            if let token = wordToIdx[word] {
                sequenceTokens.append(token)
            } else {
                print("Warning: word '\(word)' not in vocabulary, skipping")
            }
        }

        // Add ayah marker
        sequenceTokens.append(ayahToken)

        print("Sequence length before padding: \(sequenceTokens.count)")

        // Pad to maxLength using padToken
        let attentionMask = Array(repeating: 1, count: sequenceTokens.count) +
                           Array(repeating: 0, count: maxLength - sequenceTokens.count)
        sequenceTokens += Array(repeating: padToken, count: maxLength - sequenceTokens.count)

        // Create MLMultiArray inputs
        guard let inputIds = try? MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32),
              let attentionMaskArray = try? MLMultiArray(shape: [1, NSNumber(value: maxLength)], dataType: .int32) else {
            print("Error creating MLMultiArray")
            return nil
        }

        for i in 0..<maxLength {
            inputIds[[0, i] as [NSNumber]] = NSNumber(value: sequenceTokens[i])
            attentionMaskArray[[0, i] as [NSNumber]] = NSNumber(value: attentionMask[i])
        }

        // Run inference
        guard let output = try? model.prediction(from: QuranSeq2SeqInput(input_ids: inputIds, attention_mask: attentionMaskArray)),
              let logits = output.featureValue(for: "logits")?.multiArrayValue else {
            print("Error running inference")
            return nil
        }

        // Find position of الاية: marker in sequence
        guard let ayahPos = sequenceTokens.firstIndex(of: ayahToken) else {
            print("Ayah marker not found in sequence")
            return nil
        }

        print("Ayah marker position: \(ayahPos)")

        // Get predicted tokens for the 6 output positions after الاية:
        let outputLength = 6
        var predictedWords: [String] = []

        let vocabSize = wordToIdx.count
        for i in 0..<outputLength {
            let pos = ayahPos + i
            guard pos < maxLength else { break }

            // Find argmax across vocabulary for this position
            var maxLogit = -Float.infinity
            var maxIdx = 0

            for vocabIdx in 0..<vocabSize {
                let logit = logits[[0, pos, vocabIdx] as [NSNumber]].floatValue
                if logit > maxLogit {
                    maxLogit = logit
                    maxIdx = vocabIdx
                }
            }

            // Convert token to word
            if let word = idxToWord[maxIdx] {
                // Skip special tokens in output
                if word != "<s>" && word != "</s>" && word != "القاريء:" && word != "الاية:" {
                    predictedWords.append(word)
                }
            }
        }

        let predictedText = predictedWords.joined(separator: " ")
        print("Predicted ayah text: \(predictedText)")

        return predictedText
    }
}
