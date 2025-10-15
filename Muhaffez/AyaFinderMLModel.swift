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
  private let maxLength = 70

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

    // Tokenize the input
    let tokens = tokenize(text: text)

    // Create MLMultiArray input
    guard let input = try? MLMultiArray(shape: [1, 70], dataType: .int32) else {
      print("Error creating MLMultiArray")
      return nil
    }

    for i in 0..<70 {
      input[i] = NSNumber(value: tokens[i])
    }

    // Run inference
    guard let output = try? model.prediction(from: AyaFinderInput(input: input)),
          let outputArray = output.featureValue(for: "output")?.multiArrayValue else {
      print("Error running inference")
      return nil
    }

    // Get probabilities and find top 5
    var probabilities: [(index: Int, prob: Double)] = []
    for i in 0..<outputArray.count {
      let prob = outputArray[i].doubleValue
      probabilities.append((i, prob))
    }

    // Sort by probability descending
    probabilities.sort { $0.prob > $1.prob }

    let topPrediction = probabilities[0]
    let top5 = Array(probabilities.prefix(5)).map { ($0.index, $0.prob) }

    return (topPrediction.index, topPrediction.prob, top5)
  }

  private func tokenize(text: String) -> [Int] {
    let padToken = vocabulary["<PAD>"] ?? 0
    let unkToken = vocabulary["<UNK>"] ?? 1

    var tokens: [Int] = []

    // Take first 70 characters
    let prefix = String(text.prefix(70))

    for char in prefix {
      let token = vocabulary[String(char)] ?? unkToken
      tokens.append(token)
    }

    // Pad to 70
    while tokens.count < maxLength {
      tokens.append(padToken)
    }

    return Array(tokens.prefix(maxLength))
  }
}
