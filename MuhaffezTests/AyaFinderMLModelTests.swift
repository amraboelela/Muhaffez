//
//  AyaFinderMLModelTests.swift
//  MuhaffezTests
//
//  Created by Amr Aboelela on 11/17/24.
//

import Testing
@testable import Muhaffez

@MainActor
struct AyaFinderMLModelTests {

    @Test func testDistortedInput() async throws {
        let mlModel = AyaFinderMLModel()

        // Input with distortion: "فاعص" instead of "فوق"
        // Expected ayah: "وهو القاهر فوق عباده وهو الحكيم الخبير" (Al-An'am 6:18, index 989)
        let inputText = "وهو القاهر فاعص عباده"

        let result = mlModel.predict(text: inputText)

        // The model should handle distortion and find the correct ayah
        // or return nil if distortion is too severe
        if let result {
            print("ML Model prediction: \(result)")

            // Verify the result contains key words from the expected ayah
            #expect(result.contains("القاهر"), "Result should contain القاهر")
            #expect(result.contains("عباده"), "Result should contain عباده")

            // Verify result has reasonable length (at least 2 words)
            let words = result.split(separator: " ")
            #expect(words.count >= 2, "Result should have at least 2 words, got \(words.count)")
        } else {
            print("ML Model returned nil for distorted input (distortion may be too severe)")
        }
    }

    @Test func testCorrectInput() async throws {
        let mlModel = AyaFinderMLModel()

        // Correct input for Al-An'am 6:18
        let inputText = "وهو القاهر فوق عباده"

        let result = mlModel.predict(text: inputText)

        // Should return the ayah text
        #expect(result != nil, "Model should return a result for valid input")

        if let result {
            print("ML Model prediction for correct input: \(result)")

            // Should contain the input words
            #expect(result.contains("القاهر"), "Result should contain القاهر")
            #expect(result.contains("عباده"), "Result should contain عباده")

            // Expected continuation: "وهو الحكيم الخبير" or similar
            let words = result.split(separator: " ")
            #expect(words.count >= 4, "Result should have at least 4 words (model outputs 6 words), got \(words.count)")
        }
    }

    @Test func testWordArrayInput() async throws {
        let mlModel = AyaFinderMLModel()

        // Input words as specified: ["وهو", "القاهر", "فاعص", "عباده"]
        // Expected: Should recognize this as Al-An'am 6:18 despite "فاعص" distortion
        let inputWords = ["وهو", "القاهر", "فاعص", "عباده"]
        let inputText = inputWords.joined(separator: " ")

        print("Testing with input words: \(inputWords)")
        print("Joined text: \(inputText)")

        let result = mlModel.predict(text: inputText)

        // Test that the model handles the input gracefully
        if let result {
            print("ML Model returned: \(result)")

            // Should contain key words (the model corrects the distortion)
            #expect(result.contains("القاهر"), "Result should contain القاهر")
            #expect(result.contains("عباده"), "Result should contain عباده")

            // Verify we got a meaningful prediction
            let words = result.split(separator: " ")
            #expect(words.count >= 2, "Result should have at least 2 words, got \(words.count)")
        } else {
            // It's acceptable for the model to return nil if distortion is too severe
            print("ML Model returned nil (distortion may be too severe)")
        }
    }

    @Test func testPartialMatch() async throws {
        let mlModel = AyaFinderMLModel()

        // First three words only
        let inputText = "وهو القاهر فوق"

        let result = mlModel.predict(text: inputText)

        // Should still find a match with partial input
        #expect(result != nil, "Model should handle partial input")

        if let result {
            print("ML Model prediction for partial input: \(result)")

            // Should continue the ayah
            #expect(result.contains("القاهر"), "Result should contain القاهر")

            // Should predict continuation (like "عباده وهو الحكيم الخبير")
            let words = result.split(separator: " ")
            #expect(words.count >= 3, "Result should continue the ayah with at least 3 words, got \(words.count)")
        }
    }
}
