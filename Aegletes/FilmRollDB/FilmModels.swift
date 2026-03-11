//
//  FilmModels.swift
//  Aegletes
//
//  Core film domain models: formats, types, status, rolls, identity.
//

import Foundation

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
    /// Freeform notes about the roll.
    var notes: String

    // Film characteristics
    /// Manufacturer name (can be any string; use FilmRollDatabase.manufacturerOptions as suggestions).
    var manufacturer: String
    /// Stock name (can be any string; use FilmRollDatabase.stockCatalog[manufacturer] as suggestions).
    var stock: String
    var filmType: FilmType
    var format: FilmFormat
    var boxISO: Double         // nominal ISO of the film
    var effectiveISO: Double   // EI you actually shoot it at

    // Camera metadata
    var camera: String         // must come from cameraNames; defaults to "No camera"

    // Lifecycle
    var status: FilmRollStatus

    // Creation timestamp for this roll (set automatically, never user-editable).
    var dateCreated: Date

    // Records when user loads film into camera
    var dateLoaded: Date?
    // Records when the roll is finished and removed from the camera
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
        dateCreated: Date = Date(),
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
        self.dateCreated = dateCreated
        self.dateLoaded = dateLoaded
        self.dateFinished = dateFinished
        self.dateScanned = dateScanned
    }

    // MARK: - Codable with backward compatibility

    private enum CodingKeys: String, CodingKey {
        case id
        case dateCreated
        case notes
        case manufacturer
        case stock
        case filmType
        case format
        case boxISO
        case effectiveISO
        case camera
        case status
        case dateLoaded
        case dateFinished
        case dateScanned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        // Use existing value if present, else default to "now" for old JSON without this field.
        dateCreated = try c.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
        notes = try c.decode(String.self, forKey: .notes)
        manufacturer = try c.decode(String.self, forKey: .manufacturer)
        stock = try c.decode(String.self, forKey: .stock)
        filmType = try c.decode(FilmType.self, forKey: .filmType)
        format = try c.decode(FilmFormat.self, forKey: .format)
        boxISO = try c.decode(Double.self, forKey: .boxISO)
        effectiveISO = try c.decode(Double.self, forKey: .effectiveISO)
        camera = try c.decode(String.self, forKey: .camera)
        status = try c.decode(FilmRollStatus.self, forKey: .status)
        dateLoaded = try c.decodeIfPresent(Date.self, forKey: .dateLoaded)
        dateFinished = try c.decodeIfPresent(Date.self, forKey: .dateFinished)
        dateScanned = try c.decodeIfPresent(Date.self, forKey: .dateScanned)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(dateCreated, forKey: .dateCreated)
        try c.encode(notes, forKey: .notes)
        try c.encode(manufacturer, forKey: .manufacturer)
        try c.encode(stock, forKey: .stock)
        try c.encode(filmType, forKey: .filmType)
        try c.encode(format, forKey: .format)
        try c.encode(boxISO, forKey: .boxISO)
        try c.encode(effectiveISO, forKey: .effectiveISO)
        try c.encode(camera, forKey: .camera)
        try c.encode(status, forKey: .status)
        try c.encodeIfPresent(dateLoaded, forKey: .dateLoaded)
        try c.encodeIfPresent(dateFinished, forKey: .dateFinished)
        try c.encodeIfPresent(dateScanned, forKey: .dateScanned)
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

// MARK: - Film Identity (for grouping "same film")

struct FilmIdentity: Hashable {
    let manufacturer: String
    let stock: String
    let filmType: FilmType
    let format: FilmFormat
    let boxISO: Double
}

extension FilmRoll {
    var filmIdentity: FilmIdentity {
        FilmIdentity(
            manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
            stock: stock.trimmingCharacters(in: .whitespacesAndNewlines),
            filmType: filmType,
            format: format,
            boxISO: boxISO
        )
    }
}
