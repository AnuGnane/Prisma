//
//  SignalsStateSerializer.swift
//  Prisma
//
//  Serializer for converting Signals guess history to/from JSON.
//

import Foundation

/// Serializer for Signals guess history persistence.
///
/// Converts arrays of SignalsGuessWithFeedback to JSON strings for storage in GameResult
/// and reconstructs guess history from JSON strings for display in history views.
///
/// Requirements: 2.1, 2.2, 2.3, 2.4, 13.1, 13.2, 13.3, 13.4, 13.5
enum SignalsStateSerializer: GameStateSerializer {
    typealias StateType = [SignalsGuessWithFeedback]
    
    /// Serializes a Signals guess history to a JSON string.
    ///
    /// Converts the array of guesses with feedback to a serializable format,
    /// extracting digit arrays and computing correctPositions (green) and
    /// correctDigits (yellow) counts from the digitResults feedback.
    ///
    /// - Parameter state: The guess history array to serialize
    /// - Returns: JSON string representation, or nil if encoding fails
    static func serialize(_ state: [SignalsGuessWithFeedback]) -> String? {
        // Map guess history to serializable format
        let serializedGuesses = state.map { guessWithFeedback in
            // Convert digitResults to string array for position-specific preservation
            let digitResultStrings = guessWithFeedback.feedback.digitResults.map { result -> String in
                switch result {
                case .correct: return "correct"
                case .misplaced: return "misplaced"
                case .absent: return "absent"
                }
            }
            
            return SerializableSignalsGuess(
                digits: guessWithFeedback.guess.digits,
                digitResults: digitResultStrings
            )
        }
        
        // Create serializable state
        let serializableState = SerializableSignalsState(guesses: serializedGuesses)
        
        // Encode to JSON
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(serializableState)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ SignalsStateSerializer: Failed to convert data to UTF-8 string")
                return nil
            }
            return jsonString
        } catch {
            print("❌ SignalsStateSerializer: Failed to encode guess history - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Deserializes a JSON string to a Signals guess history.
    ///
    /// Reconstructs the array of SignalsGuessWithFeedback from the serialized format,
    /// converting correctPositions and correctDigits counts back to digitResults arrays.
    /// Note: This reconstruction creates a simplified feedback that only preserves
    /// the counts, not the exact positions of correct/misplaced digits.
    ///
    /// - Parameter json: JSON string to deserialize
    /// - Returns: Reconstructed guess history array, or nil if deserialization fails
    static func deserialize(_ json: String) -> [SignalsGuessWithFeedback]? {
        // Convert string to data
        guard let data = json.data(using: .utf8) else {
            print("❌ SignalsStateSerializer: Invalid UTF-8 encoding")
            return nil
        }
        
        // Decode JSON
        let decoder = JSONDecoder()
        let state: SerializableSignalsState
        do {
            state = try decoder.decode(SerializableSignalsState.self, from: data)
        } catch {
            print("❌ SignalsStateSerializer: Failed to decode JSON - \(error.localizedDescription)")
            return nil
        }
        
        // Reconstruct guess history
        let guessHistory = state.guesses.map { serializedGuess in
            let guess = SignalsGuess(digits: serializedGuess.digits)
            
            // Reconstruct digitResults array from position-specific strings
            let digitResults = serializedGuess.digitResults.map { resultString -> DigitResult in
                switch resultString {
                case "correct": return .correct
                case "misplaced": return .misplaced
                default: return .absent
                }
            }
            
            let feedback = SignalsFeedback(
                digitResults: digitResults,
                valueHint: .exact
            )
            
            return SignalsGuessWithFeedback(guess: guess, feedback: feedback)
        }
        
        return guessHistory
    }
}
