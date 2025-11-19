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
        guard let model else {
            print("Model not loaded")
            return nil
        }

        // Normalize the input text
        //let normalizedText = text.normalizedArabic

        // Split into words
        let inputWords = text.split(separator: " ").map { String($0) }

        guard !inputWords.isEmpty else {
            print("No input words after normalization")
            return nil
        }

        print("Input words: \(inputWords)")

        // Build sequence: <s> القاريء: [input_words] الاية:
        var sequenceTokens = [bosToken, readerToken]

        // Add input word tokens (limit to first 6 words to leave room for output)
        let maxInputWords = min(inputWords.count, 6)
        var skippedWords = 0
        for i in 0..<maxInputWords {
            let word = inputWords[i]
            if let token = wordToIdx[word] {
                sequenceTokens.append(token)
            } else {
                print("Warning: word '\(word)' not in vocabulary, skipping")
                skippedWords += 1
            }
        }

        // Add ayah marker
        sequenceTokens.append(ayahToken)

        let actualInputTokens = sequenceTokens.count - 3  // Subtract <s>, القاريء:, الاية:
        print("Initial sequence length: \(sequenceTokens.count) (before generation)")
        print("Input tokens added: \(actualInputTokens) (skipped \(skippedWords) OOV words)")

        // If we have less than 3 input words in vocabulary, return nil
        if actualInputTokens < 2 {
            print("Not enough vocabulary words (need at least 3, got \(actualInputTokens)), cannot make prediction")
            return nil
        }

        // Autoregressive generation: predict one token at a time
        var predictedWords: [String] = []
        let maxOutputWords = 6

        for _ in 0..<maxOutputWords {
            // Create MLMultiArray for current sequence (NO PADDING)
            let currentLength = sequenceTokens.count
            guard let inputIds = try? MLMultiArray(shape: [1, NSNumber(value: currentLength)], dataType: .int32),
                  let attentionMaskArray = try? MLMultiArray(shape: [1, NSNumber(value: currentLength)], dataType: .int32) else {
                print("Error creating MLMultiArray")
                return nil
            }

            // Fill arrays with current sequence
            for i in 0..<currentLength {
                inputIds[[0, i] as [NSNumber]] = NSNumber(value: sequenceTokens[i])
                attentionMaskArray[[0, i] as [NSNumber]] = NSNumber(value: 1)  // All real tokens
            }

            // Run inference
            let output: MLFeatureProvider
            do {
                output = try model.prediction(from: QuranSeq2SeqInput(input_ids: inputIds, attention_mask: attentionMaskArray))
            } catch {
                print("Error running inference: \(error)")
                print("  Current sequence length: \(currentLength)")
                print("  Input shape: [\(1), \(currentLength)]")
                return nil
            }

            guard let logits = output.featureValue(for: "logits")?.multiArrayValue else {
                print("Error: Could not get logits from model output")
                return nil
            }

            // Get prediction for the LAST position (next token)
            let lastPos = currentLength - 1
            var maxLogit = -Float.infinity
            var maxIdx = 0

            let vocabSize = wordToIdx.count
            for vocabIdx in 0..<vocabSize {
                let logit = logits[[0, lastPos, vocabIdx] as [NSNumber]].floatValue
                if logit > maxLogit {
                    maxLogit = logit
                    maxIdx = vocabIdx
                }
            }

            // Stop if we predict </s>
            if maxIdx == eosToken {
                break
            }

            // Append predicted token to sequence for next iteration
            sequenceTokens.append(maxIdx)

            // Convert token to word and add to output (skip special tokens)
            if let word = idxToWord[maxIdx] {
                if word != "<s>" && word != "</s>" && word != "القاريء:" && word != "الاية:" && word != "<pad>" {
                    predictedWords.append(word)
                }
            }
        }

        let predictedText = predictedWords.joined(separator: " ")
        print("Predicted ayah text: \(predictedText)")

        return predictedText
    }
}
