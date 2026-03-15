//
//  FilmRollStore.swift
//  Aegletes
//
//  ObservableObject wrapper around FilmRollDatabase (JSON-backed).
//

import Foundation
import Combine

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
            url = (try? FilmRollDatabase.defaultStoreURL()) ??
                  URL(fileURLWithPath: "/dev/null")
        }
        self.storeURL = url

        // Load existing or start fresh
        self.database = FilmRollDatabase.load(from: url)

        // Autosave on any database change
        autosaveCancellable = $database
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] db in
                guard let self = self else { return }
                db.save(to: self.storeURL)
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

    func removeCameraName(_ name: String) {
        database.removeCameraName(name)
    }

    /// Force a save immediately (e.g. on app background).
    func saveNow() {
        database.save(to: storeURL)
    }
}

// MARK: - Shared "Load Roll into Camera" backend logic

extension FilmRollStore {
    /// Load a roll into a camera with a specific effective ISO.
    /// - Validates camera / ISO, updates camera + EI, and sets status to .loaded with dateLoaded.
    func loadRoll(id: UUID, camera: String, effectiveISO: Double, at date: Date = Date()) {
        let trimmed = camera.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            trimmed != "No camera",
            FilmRollDatabase.effectiveISOOptions.contains(effectiveISO),
            let idx = database.rolls.firstIndex(where: { $0.id == id })
        else {
            return
        }

        var roll = database.rolls[idx]
        roll.camera = trimmed
        roll.effectiveISO = effectiveISO
        roll.updateStatus(to: .loaded, at: date)
        database.updateRoll(roll)
    }
    //  Update the stack count of the Stack. Will need to add an error or warning if the user tries to remove more rolls than possible
    func setStackCount(for identity: FilmIdentity, to targetCount: Int) {
        let allRollsForIdentity = rolls.filter { $0.filmIdentity == identity }
        let currentCount = allRollsForIdentity.count
        let target = max(1, targetCount)

        if target > currentCount {
            let extra = target - currentCount
            let template = allRollsForIdentity.first!
            for _ in 0..<extra {
                let newRoll = FilmRoll(
                    notes: template.notes,
                    manufacturer: template.manufacturer,
                    stock: template.stock,
                    filmType: template.filmType,
                    format: template.format,
                    boxISO: template.boxISO,
                    effectiveISO: template.effectiveISO,
                    camera: "No camera",
                    status: .inStorage
                )
                addRoll(newRoll)
            }
        } else if target < currentCount {
            let needed = currentCount - target
            let candidates = allRollsForIdentity.filter { $0.status == .inStorage }
            let toRemove = Array(candidates.prefix(needed))
            for r in toRemove {
                removeRoll(r)
            }
        }
    }
}

extension FilmRollStore {
    /// Returns another roll that is currently loaded in the given camera,
    /// excluding the roll with the specified id. Returns nil if no conflict.
    func loadedRoll(in camera: String, excluding rollID: UUID) -> FilmRoll? {
        let trimmed = camera.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return rolls.first(where: {
            $0.id != rollID &&
            $0.status == .loaded &&
            $0.camera.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed
        })
    }
}

// MARK: - Bulk identity update for stacks
extension FilmRollStore {
    /// Update the "identity" fields (manufacturer/stock/type/format/boxISO)
    /// for all rolls that match a given FilmIdentity.
    func updateIdentityForAllRolls(
        in originalIdentity: FilmIdentity,
        to newIdentity: FilmIdentity
    ) {
        for idx in database.rolls.indices {
            if database.rolls[idx].filmIdentity == originalIdentity {
                database.rolls[idx].manufacturer = newIdentity.manufacturer
                database.rolls[idx].stock        = newIdentity.stock
                database.rolls[idx].filmType     = newIdentity.filmType
                database.rolls[idx].format       = newIdentity.format
                database.rolls[idx].boxISO       = newIdentity.boxISO
            }
        }
    }
}
