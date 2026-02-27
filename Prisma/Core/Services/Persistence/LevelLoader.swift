//
//  LevelLoader.swift
//  Prisma
//
//  Loads Codable level data from JSON files bundled in Resources/LevelData/.
//

import Foundation

enum LevelLoaderError: LocalizedError {
    case fileNotFound(String)
    case decodingFailed(String, Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let name):
            return "Level file '\(name)' not found in bundle."
        case .decodingFailed(let name, let error):
            return "Failed to decode '\(name)': \(error.localizedDescription)"
        }
    }
}

struct LevelLoader {
    /// Loads and decodes an array of levels from a JSON file in the app bundle.
    /// - Parameter filename: Name without extension, e.g. "signals_levels"
    static func load<T: Decodable>(_ filename: String) throws -> T {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            throw LevelLoaderError.fileNotFound(filename)
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as LevelLoaderError {
            throw error
        } catch {
            throw LevelLoaderError.decodingFailed(filename, error)
        }
    }
}
