//
// FilmRollDatabase.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/7/26.
// Edited on 3/8/26 - FilmType, notes, JSON DB, store, and camera list support
//

import Foundation
import Combine

// MARK: - Supporting Types

enum FilmFormat: String, CaseIterable, Codable, Identifiable {
    case thirtyFive = "35mm"
    case oneTwenty  = "120mm"
    case large      = "Large Format"

    var id: String { rawValue }
}

enum FilmRollStatus: String, CaseIterable, Codable, Identifiable {
    case inStorage  = "In Storage"
    case loaded     = "Loaded"
    case finished   = "Finished"
    case developed  = "Developed"
    case scanning   = "Scanning"
    case archived   = "Archived"

    var id: String { rawValue }
}

enum FilmType: String, CaseIterable, Codable, Identifiable {
    case bw    = "B&W"
    case color = "Color"
    case slide = "Slide"

    var id: String { rawValue }
}

// MARK: - Core Entity

struct FilmRoll: Identifiable, Codable, Equatable {
    // Core identity
    var id: UUID

    // Notes / label
    /// Freeform notes about the roll (was previously "label").
    var notes: String

    // Film characteristics
    /// Manufacturer name (can be any string; use FilmRollDatabase.manufacturerOptions as suggestions).
    var manufacturer: String
    /// Stock name (can be any string; use FilmRollDatabase.stockCatalog[manufacturer] as suggestions).
    var stock: String
    var filmType: FilmType
    var format: FilmFormat
    var boxISO: Double         // nominal ISO of the film
    var effectiveISO: Double   // EI you actually rate it at

    // Camera metadata
    var camera: String         // must come from cameraNames; defaults to "No camera"

    // Lifecycle
    var status: FilmRollStatus
    var dateLoaded: Date?
    var dateFinished: Date?
    /// Records when status first becomes .archived (treated as "dateScanned" per requirements).
    var dateScanned: Date?

    init(
        id: UUID = UUID(),
        notes: String,
        manufacturer: String,
        stock: String,
        filmType: FilmType,
        format: FilmFormat,
        boxISO: Double,
        effectiveISO: Double,
        camera: String,
        status: FilmRollStatus = .inStorage,
        dateLoaded: Date? = nil,
        dateFinished: Date? = nil,
        dateScanned: Date? = nil
    ) {
        self.id = id
        self.notes = notes
        self.manufacturer = manufacturer
        self.stock = stock
        self.filmType = filmType
        self.format = format
        self.boxISO = boxISO
        self.effectiveISO = effectiveISO
        self.camera = camera
        self.status = status
        self.dateLoaded = dateLoaded
        self.dateFinished = dateFinished
        self.dateScanned = dateScanned
    }

    /// Update status and automatically set key dates on first transition:
    /// - dateLoaded   when status becomes .loaded
    /// - dateFinished when status becomes .finished
    /// - dateScanned  when status becomes .archived
    mutating func updateStatus(to newStatus: FilmRollStatus, at date: Date = Date()) {
        let previous = status
        status = newStatus

        if newStatus == .loaded, previous != .loaded, dateLoaded == nil {
            dateLoaded = date
        }
        if newStatus == .finished, previous != .finished, dateFinished == nil {
            dateFinished = date
        }
        if newStatus == .archived, previous != .archived, dateScanned == nil {
            dateScanned = date
        }
    }
}

// MARK: - Film Roll Database (JSON-backed, plus option catalogs)

struct FilmRollDatabase: Codable {
    // Stored rolls
    var rolls: [FilmRoll] = []

    // User-entered camera names (for auto-complete / pickers)
    private var cameraNameSet: Set<String> = ["No camera"]

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
    }

    var cameraNames: [String] {
        Array(cameraNameSet).sorted()
    }

    // Rebuild camera name set from rolls if needed
    mutating func rebuildCameraNames() {
        cameraNameSet = ["No camera"]
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
        rebuildCameraNames()
    }

    mutating func removeRoll(_ roll: FilmRoll) {
        removeRoll(withId: roll.id)
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

    /// Load database from a JSON file at the given URL. Returns empty DB on failure.
    static func load(from url: URL) -> FilmRollDatabase {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var db = try decoder.decode(FilmRollDatabase.self, from: data)
            db.rebuildCameraNames()
            return db
        } catch {
            return FilmRollDatabase()
        }
    }

    /// Save database to a JSON file at the given URL.
    func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: [.atomic])
    }
}

// MARK: - FilmRollStore (ObservableObject wrapper around JSON DB)

final class FilmRollStore: ObservableObject {
    @Published private(set) var database: FilmRollDatabase

    private let storeURL: URL
    private var autosaveCancellable: AnyCancellable?

    init(storeURL: URL? = nil) {
        // Determine URL
        let url: URL
        if let custom = storeURL {
            url = custom
        } else {
            url = (try? FilmRollDatabase.defaultStoreURL()) ?? URL(fileURLWithPath: "/dev/null")
        }
        self.storeURL = url

        // Load existing or start fresh
        self.database = FilmRollDatabase.load(from: url)

        // Autosave on any database change
        autosaveCancellable = $database
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] db in
                guard let self = self else { return }
                do {
                    try db.save(to: self.storeURL)
                } catch {
                    // For now, ignore save errors; could add logging later.
                }
            }
    }

    // MARK: - Accessors

    var rolls: [FilmRoll] {
        database.rolls
    }

    var cameraNames: [String] {
        database.cameraNames
    }

    // MARK: - Mutating Operations

    func addRoll(_ roll: FilmRoll) {
        database.addRoll(roll)
    }

    func updateRoll(_ roll: FilmRoll) {
        database.updateRoll(roll)
    }

    func removeRoll(withId id: UUID) {
        database.removeRoll(withId: id)
    }

    func removeRoll(_ roll: FilmRoll) {
        database.removeRoll(roll)
    }

    func updateStatus(forRollId id: UUID, to newStatus: FilmRollStatus, at date: Date = Date()) {
        guard let idx = database.rolls.firstIndex(where: { $0.id == id }) else { return }
        var roll = database.rolls[idx]
        roll.updateStatus(to: newStatus, at: date)
        database.updateRoll(roll)
    }

    func addCameraName(_ name: String) {
        database.registerCameraName(name)
    }

    /// Force a save immediately (e.g. on app background).
    func saveNow() {
        do {
            try database.save(to: storeURL)
        } catch {
            // Ignore or log
        }
    }
}
