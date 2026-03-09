//
//  ShiftPuzzleLoader.swift
//  Prisma
//
//  Created by Kiro on 2024
//

import Foundation

/// Loads Shift puzzle levels from JSON files.
/// Handles level data loading, parsing, and conversion to ShiftPuzzle instances.
/// 
/// **Validates: Requirements 11.2, 29.1, 29.2, 29.4**
struct ShiftPuzzleLoader {
    
    // MARK: - Single Level Loading
    
    /// Loads a specific level by ID from the shift_levels.json file.
    /// 
    /// This method:
    /// - Locates the shift_levels.json file in Resources/LevelData
    /// - Parses the JSON to an array of ShiftLevelData
    /// - Finds the level matching the specified ID
    /// - Converts the level data to a ShiftPuzzle
    /// - Returns nil on any error with helpful logging
    /// 
    /// - Parameter levelId: The unique identifier for the level to load (1-100)
    /// - Returns: A ShiftPuzzle if the level is found and valid, nil otherwise
    /// 
    /// **Validates: Requirements 11.2, 29.1, 29.2, 29.4**
    static func loadLevel(_ levelId: Int) -> ShiftPuzzle? {
        // Locate the JSON file in the bundle
        guard let url = Bundle.main.url(
            forResource: "shift_levels",
            withExtension: "json"
        ) else {
            print("❌ ShiftPuzzleLoader: shift_levels.json not found")
            return nil
        }
        
        // Load and parse the JSON file
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let levels = try decoder.decode([ShiftLevelData].self, from: data)
            
            // Find the level with the matching ID
            guard let levelData = levels.first(where: { $0.levelId == levelId }) else {
                print("❌ ShiftPuzzleLoader: Level \(levelId) not found in shift_levels.json")
                return nil
            }
            
            // Convert to ShiftPuzzle
            guard let puzzle = levelData.toPuzzle() else {
                print("❌ ShiftPuzzleLoader: Failed to convert level \(levelId) to ShiftPuzzle")
                return nil
            }
            
            return puzzle
            
        } catch let decodingError as DecodingError {
            print("❌ ShiftPuzzleLoader: JSON decoding error - \(decodingError.localizedDescription)")
            return nil
        } catch {
            print("❌ ShiftPuzzleLoader: Failed to load shift_levels.json - \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Batch Loading
    
    /// Loads all levels from the shift_levels.json file.
    /// 
    /// This method:
    /// - Locates the shift_levels.json file in Resources/LevelData
    /// - Parses the JSON to an array of ShiftLevelData
    /// - Converts all valid level data to ShiftPuzzle instances
    /// - Filters out any invalid levels (logs errors for each)
    /// - Returns an empty array on file loading errors
    /// 
    /// - Returns: An array of ShiftPuzzle instances for all valid levels
    /// 
    /// **Validates: Requirements 29.1, 29.2, 29.4**
    static func loadAllLevels() -> [ShiftPuzzle] {
        // Locate the JSON file in the bundle
        guard let url = Bundle.main.url(
            forResource: "shift_levels",
            withExtension: "json"
        ) else {
            print("❌ ShiftPuzzleLoader: shift_levels.json not found")
            return []
        }
        
        // Load and parse the JSON file
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let levels = try decoder.decode([ShiftLevelData].self, from: data)
            
            // Convert all levels to puzzles, filtering out invalid ones
            let puzzles = levels.compactMap { levelData -> ShiftPuzzle? in
                guard let puzzle = levelData.toPuzzle() else {
                    print("⚠️ ShiftPuzzleLoader: Skipping invalid level \(levelData.levelId)")
                    return nil
                }
                return puzzle
            }
            
            print("✅ ShiftPuzzleLoader: Successfully loaded \(puzzles.count) levels")
            return puzzles
            
        } catch let decodingError as DecodingError {
            print("❌ ShiftPuzzleLoader: JSON decoding error - \(decodingError.localizedDescription)")
            return []
        } catch {
            print("❌ ShiftPuzzleLoader: Failed to load shift_levels.json - \(error.localizedDescription)")
            return []
        }
    }
}
