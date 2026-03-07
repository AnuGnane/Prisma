//
//  ArchiveStateSerializer.swift
//  Prisma
//
//  Serializer for converting Archive guess history to/from JSON.
//

import Foundation

/// Serializer for Archive game state persistence.
///
/// Converts Archive guess history (array of ArchiveGuessWithFeedback) to JSON strings
/// for storage in GameResult and reconstructs guess history from JSON strings for
/// display in history views.
///
/// Requirements: 3.1, 3.2, 3.3, 3.4, 14.1, 14.2, 14.3, 14.4, 14.5
enum ArchiveStateSerializer: GameStateSerializer {
    typealias StateType = [ArchiveGuessWithFeedback]
    
    /// Serializes Archive guess history to a JSON string.
    ///
    /// Converts the array of guesses with feedback to a serializable format,
    /// mapping DigitResult enums to strings and preserving the ValueHint.
    ///
    /// - Parameter state: The guess history to serialize
    /// - Returns: JSON string representation, or nil if encoding fails
    static func serialize(_ state: [ArchiveGuessWithFeedback]) -> String? {
        // Map guesses to serializable format
        let serializedGuesses = state.map { guessWithFeedback in
            // Convert digit results to strings
            let digitResultStrings = guessWithFeedback.feedback.digitResults.map { result in
                switch result {
                case .correct: return "correct"
                case .misplaced: return "misplaced"
                case .absent: return "absent"
                }
            }
            
            // Convert value hint to string
            let valueHintString: String
            switch guessWithFeedback.feedback.valueHint {
            case .high: valueHintString = "high"
            case .low: valueHintString = "low"
            case .exact: valueHintString = "exact"
            }
            
            return SerializableArchiveGuess(
                digits: guessWithFeedback.guess.digits,
                digitResults: digitResultStrings,
                valueHint: valueHintString
            )
        }
        
        // Create serializable state
        let serializableState = SerializableArchiveState(guesses: serializedGuesses)
        
        // Encode to JSON
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(serializableState)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ ArchiveStateSerializer: Failed to convert data to UTF-8 string")
                return nil
            }
            return jsonString
        } catch {
            print("❌ ArchiveStateSerializer: Failed to encode guess history - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Deserializes a JSON string to Archive guess history.
    ///
    /// Reconstructs the array of ArchiveGuessWithFeedback from JSON, converting
    /// string representations back to DigitResult and ValueHint enums.
    ///
    /// - Parameter json: JSON string to deserialize
    /// - Returns: Reconstructed guess history, or nil if deserialization fails
    static func deserialize(_ json: String) -> [ArchiveGuessWithFeedback]? {
        // Convert string to data
        guard let data = json.data(using: .utf8) else {
            print("❌ ArchiveStateSerializer: Invalid UTF-8 encoding")
            return nil
        }
        
        // Decode JSON
        let decoder = JSONDecoder()
        let state: SerializableArchiveState
        do {
            state = try decoder.decode(SerializableArchiveState.self, from: data)
        } catch {
            print("❌ ArchiveStateSerializer: Failed to decode JSON - \(error.localizedDescription)")
            return nil
        }
        
        // Reconstruct guess history
        let guesses = state.guesses.compactMap { serialized -> ArchiveGuessWithFeedback? in
            // Convert digit result strings back to enums
            let digitResults: [DigitResult] = serialized.digitResults.compactMap { resultString in
                switch resultString {
                case "correct": return .correct
                case "misplaced": return .misplaced
                case "absent": return .absent
                default:
                    print("⚠️ ArchiveStateSerializer: Unknown digit result '\(resultString)', treating as absent")
                    return .absent
                }
            }
            
            // Ensure we have exactly 8 digit results
            guard digitResults.count == 8 else {
                print("⚠️ ArchiveStateSerializer: Expected 8 digit results, got \(digitResults.count)")
                return nil
            }
            
            // Convert value hint string back to enum
            let valueHint: ValueHint
            switch serialized.valueHint {
            case "high": valueHint = .high
            case "low": valueHint = .low
            case "exact": valueHint = .exact
            default:
                print("⚠️ ArchiveStateSerializer: Unknown value hint '\(serialized.valueHint)', treating as exact")
                valueHint = .exact
            }
            
            // Create guess and feedback
            let guess = ArchiveGuess(digits: serialized.digits)
            let feedback = ArchiveFeedback(digitResults: digitResults, valueHint: valueHint)
            
            return ArchiveGuessWithFeedback(guess: guess, feedback: feedback)
        }
        
        return guesses
    }
}
