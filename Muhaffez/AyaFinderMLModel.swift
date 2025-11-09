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
    private var vocabulary: [String: Int] = [:]
    private let maxLength = 60

    init() {
        loadModel()
        loadVocabulary()
    }

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            model = try AyaFinder(configuration: config).model
            print("AyaFinder model loaded successfully")
        } catch {
            print("Error loading AyaFinder model: \(error)")
        }
    }

    private func loadVocabulary() {
        guard let url = Bundle.main.url(forResource: "vocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let charToToken = json["char_to_token"] as? [String: Int] else {
            print("Error loading vocabulary")
            return
        }
        vocabulary = charToToken
        print("Vocabulary loaded: \(vocabulary.count) tokens")
    }

    func predict(text: String) -> (ayahIndex: Int, probability: Double, top5: [(Int, Double)])? {
        guard let model = model else { return nil }

        // Normalize the input text using String extension
        let normalizedText = text.normalizedArabic

        // Tokenize the normalized input (limit to 60 chars)
        let tokens = tokenize(text: normalizedText)

        // Create MLMultiArray input
        guard let input = try? MLMultiArray(shape: [1, 60], dataType: .int32) else {
            print("Error creating MLMultiArray")
            return nil
        }

        for i in 0..<60 {
            input[i] = NSNumber(value: tokens[i])
        }

        // Run inference
        guard let output = try? model.prediction(from: AyaFinderInput(input: input)),
              let outputArray = output.featureValue(for: "output")?.multiArrayValue else {
            print("Error running inference")
            return nil
        }

        // Get logits and apply softmax to get probabilities
        var logits: [Double] = []
        for i in 0..<outputArray.count {
            logits.append(outputArray[i].doubleValue)
        }

        // Apply softmax: exp(x) / sum(exp(x))
        let maxLogit = logits.max() ?? 0
        let expLogits = logits.map { exp($0 - maxLogit) }  // subtract max for numerical stability
        let sumExp = expLogits.reduce(0, +)
        let probabilities = expLogits.map { $0 / sumExp }

        // Create array with indices and probabilities
        var indexedProbs: [(index: Int, prob: Double)] = []
        for (i, prob) in probabilities.enumerated() {
            indexedProbs.append((i+1, prob))
        }

        // Sort by probability descending
        indexedProbs.sort { $0.prob > $1.prob }

        let topPrediction = indexedProbs[0]
        let top5 = Array(indexedProbs.prefix(5)).map { ($0.index, $0.prob) }

        return (topPrediction.index, topPrediction.prob, top5)
    }

    private func tokenize(text: String) -> [Int] {
        let padToken = vocabulary["<PAD>"] ?? 0
        let unkToken = vocabulary["<UNK>"] ?? 1

        var tokens: [Int] = []

        // Take first 60 characters
        let prefix = String(text.prefix(60))

        for char in prefix {
            let token = vocabulary[String(char)] ?? unkToken
            tokens.append(token)
        }

        // Pad to 60
        while tokens.count < maxLength {
            tokens.append(padToken)
        }

        return Array(tokens.prefix(maxLength))
    }
}
