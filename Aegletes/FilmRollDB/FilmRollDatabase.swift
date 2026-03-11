//
//  FilmRollDatabase.swift
//  Aegletes
//
//  Created by Nadir Pozegija on 3/7/26.
//  Edited on 3/8/26 - FilmType, notes, JSON DB, store, camera list management, FilmIdentity
//  Edited on 3/9/26 - Preserve cameraNames independent of rolls (no clearing when rolls = []).
//  Edited on 3/9/26 - Added FilmRollStore.loadRoll(...) for shared "load into camera" workflow.
//  Edited on 3//11/26 - Added error handling and logging to the Database JSON load/decode functions.
//  this serves as a checkpoint for Prod3
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.aegletes.app", category: "FilmRollDatabase")

// MARK: - Film Roll Database (JSON-backed, plus option catalogs)

struct FilmRollDatabase: Codable {
    // Stored rolls
    var rolls: [FilmRoll] = []

    // User-entered camera names (for auto-complete / pickers)
    private var cameraNameSet: Set = ["No camera"]

    // MARK: - Option Catalogs (suggestions only)

    /// Common manufacturers (user can still enter any custom string).
    static let manufacturerOptions: [String] = [
        "Kodak",
        "Ilford",
        "Cinestill",
        "Fuji",
        "Lomography",
        "Foma",
        "Harman"
    ]

    /// Common film stocks per manufacturer (user can still type any custom stock name).
    static let stockCatalog: [String: [String]] = [
        "Kodak": [
            "Portra 160",
            "Portra 400",
            "Portra 800",
            "Ektar 100",
            "Gold 200",
            "Ultramax 400",
            "ColorPlus 200",
            "Tri-X 400",
            "T-Max 100",
            "T-Max 400",
            "Ektachrome E100"
        ],
        "Ilford": [
            "HP5+ 400",
            "FP4+ 125",
            "Delta 100",
            "Delta 400",
            "Delta 3200",
            "Pan F 50",
            "XP2 Super 400"
        ],
        "Cinestill": [
            "800T",
            "400D",
            "50D",
            "BwXX"
        ],
        "Fuji": [
            "Superia X-TRA 400",
            "Superia 200",
            "C200",
            "Pro 400H",
            "Velvia 50",
            "Velvia 100",
            "Provia 100F",
            "Neopan Acros 100 II"
        ],
        "Lomography": [
            "Color Negative 100",
            "Color Negative 400",
            "Color Negative 800",
            "LomoChrome Purple",
            "LomoChrome Metropolis",
            "LomoChrome Turquoise"
        ],
        "Foma": [
            "Fomapan 100",
            "Fomapan 200",
            "Fomapan 400"
        ],
        "Harman": [
            "Phoenix I",
            "Phoenix II",
            "Red 125",
            "Switch Azure"
        ]
    ]

    /// Common formats.
    static let formatOptions: [FilmFormat] = FilmFormat.allCases

    /// Film type options.
    static let filmTypeOptions: [FilmType] = FilmType.allCases

    /// Box ISO options (copied from ExposureModel.swift: isoValues).
    static let boxISOOptions: [Double] = [
        12, 16, 20,
        25, 32, 40,
        50, 64, 80,
        100, 125, 160,
        200, 250, 320,
        400, 500, 640,
        800, 1000, 1250,
        1600, 2000, 2500,
        3200, 4000, 5000,
        6400
    ]

    /// Effective ISO options (a separate instance, same values as boxISOOptions).
    static let effectiveISOOptions: [Double] = boxISOOptions

    /// Status options.
    static let statusOptions: [FilmRollStatus] = FilmRollStatus.allCases

    // MARK: - Camera Names

    mutating func registerCameraName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cameraNameSet.insert(trimmed)
        // Always ensure the sentinel exists
        cameraNameSet.insert("No camera")
    }

    var cameraNames: [String] {
        Array(cameraNameSet).sorted()
    }

    /// Rebuild camera name set **without** losing existing user-entered names.
    /// - Ensures "No camera" is present.
    /// - Adds any camera names referenced by rolls.
    mutating func rebuildCameraNames() {
        // Ensure sentinel
        cameraNameSet.insert("No camera")
        // Merge any cameras used in existing rolls
        for roll in rolls {
            let trimmed = roll.camera.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                cameraNameSet.insert(trimmed)
            }
        }
    }

    // MARK: - Roll Management Helpers

    mutating func addRoll(_ roll: FilmRoll) {
        var r = roll
        let trimmedCamera = r.camera.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCamera.isEmpty {
            r.camera = "No camera"
        }
        rolls.append(r)
        registerCameraName(r.camera)
    }

    mutating func updateRoll(_ roll: FilmRoll) {
        var r = roll
        let trimmedCamera = r.camera.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCamera.isEmpty {
            r.camera = "No camera"
        }
        if let idx = rolls.firstIndex(where: { $0.id == r.id }) {
            rolls[idx] = r
            registerCameraName(r.camera)
        }
    }

    mutating func removeRoll(withId id: UUID) {
        rolls.removeAll { $0.id == id }
        // Keep cameraNameSet as independent store; just ensure sentinel + roll cameras are merged.
        rebuildCameraNames()
    }

    mutating func removeRoll(_ roll: FilmRoll) {
        removeRoll(withId: roll.id)
    }

    /// Remove a camera name from the catalog and reassign any rolls using it to "No camera".
    mutating func removeCameraName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "No camera" else { return }

        // Reassign all rolls that used this camera to "No camera"
        for idx in rolls.indices {
            let rollCamera = rolls[idx].camera.trimmingCharacters(in: .whitespacesAndNewlines)
            if rollCamera == trimmed {
                rolls[idx].camera = "No camera"
            }
        }

        // Remove from independent camera set
        cameraNameSet.remove(trimmed)

        // Ensure sentinel and any in-use cameras are merged back
        rebuildCameraNames()
    }

    // MARK: - Persistence (JSON file)

    /// Default URL for storing the film database JSON.
    static func defaultStoreURL() throws -> URL {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "FilmRollDatabase",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to find documents directory"]
            )
        }
        return docs.appendingPathComponent("FilmRollDatabase.json")
    }

    /// Load database from a JSON file at the given URL.
    /// Returns empty DB on failure.
    static func load(from url: URL) -> FilmRollDatabase {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let data = try Data(contentsOf: url)
            let db = try decoder.decode(FilmRollDatabase.self, from: data)
            // Ensure camera names are coherent with rolls
            var mutableDB = db
            mutableDB.rebuildCameraNames()
            return mutableDB
        } catch {
            logger.error("Failed to load FilmRollDatabase from \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            // Fall back to an empty DB rather than crashing
            return FilmRollDatabase(rolls: [], cameraNameSet: ["No camera"])
        }
    }

    /// Save database to a JSON file at the given URL.
    func save(to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]

        let fm = FileManager.default
        let backupURL = url.appendingPathExtension("bak")

        do {
            // If there is an existing DB file, back it up first
            if fm.fileExists(atPath: url.path) {
                // Remove old backup if present
                if fm.fileExists(atPath: backupURL.path) {
                    do {
                        try fm.removeItem(at: backupURL)
                    } catch {
                        logger.error("Failed to remove old FilmRollDatabase backup at \(backupURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    }
                }

                do {
                    try fm.copyItem(at: url, to: backupURL)
                    logger.debug("Backed up FilmRollDatabase to \(backupURL.path, privacy: .public)")
                } catch {
                    logger.error("Failed to create FilmRollDatabase backup at \(backupURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }

            let data = try encoder.encode(self)
            try data.write(to: url, options: [.atomic])
            logger.debug("Saved FilmRollDatabase to \(url.path, privacy: .public)")
        } catch {
            logger.error("Failed to save FilmRollDatabase to \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
