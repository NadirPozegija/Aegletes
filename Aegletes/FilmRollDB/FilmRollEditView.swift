//
//  FilmRollEditView.swift
//  Aegletes
//
//  Edit existing roll and adjust stack size for its identity.
//

import SwiftUI

struct FilmRollEditView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    let roll: FilmRoll
    let onComplete: (FilmRoll?) -> Void

    @State private var notes: String
    @State private var manufacturer: String
    @State private var stock: String
    @State private var filmType: FilmType
    @State private var format: FilmFormat
    @State private var boxISO: Double
    @State private var effectiveISO: Double
    @State private var camera: String
    @State private var rollCountText: String = "1"

    // Dates for editing (loaded / finished / scanned)
    @State private var dateLoaded: Date?
    @State private var dateFinished: Date?
    @State private var dateScanned: Date?

    init(roll: FilmRoll, onComplete: @escaping (FilmRoll?) -> Void) {
        self.roll = roll
        self.onComplete = onComplete

        _notes = State(initialValue: roll.notes)
        _manufacturer = State(initialValue: roll.manufacturer)
        _stock = State(initialValue: roll.stock)
        _filmType = State(initialValue: roll.filmType)
        _format = State(initialValue: roll.format)
        _boxISO = State(initialValue: roll.boxISO)
        _effectiveISO = State(initialValue: roll.effectiveISO)
        _camera = State(initialValue: roll.camera)

        _dateLoaded = State(initialValue: roll.dateLoaded)
        _dateFinished = State(initialValue: roll.dateFinished)
        _dateScanned = State(initialValue: roll.dateScanned)
    }

    var body: some View {
        Form {
            Section(header: Text("Film")) {
                TextField("Notes", text: $notes, axis: .vertical)

                Picker("Manufacturer", selection: $manufacturer) {
                    ForEach(FilmRollDatabase.manufacturerOptions, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }

                TextField("Or enter custom manufacturer", text: $manufacturer).bold().italic()

                if let stocks = FilmRollDatabase.stockCatalog[manufacturer], !stocks.isEmpty {
                    Picker("Stock", selection: $stock) {
                        ForEach(stocks, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                }

                TextField("Or enter custom stock", text: $stock).bold().italic()
                
                Picker("Film Type", selection: $filmType) {
                    ForEach(FilmRollDatabase.filmTypeOptions) { t in
                        Text(t.rawValue).tag(t)
                    }
                }

                Picker("Format", selection: $format) {
                    ForEach(FilmRollDatabase.formatOptions) { f in
                        Text(f.rawValue).tag(f)
                    }
                }

                Picker("Box ISO", selection: $boxISO) {
                    ForEach(FilmRollDatabase.boxISOOptions, id: \.self) { iso in
                            Text("ISO \(Int(iso))").tag(iso)
                    }
                }
            }

            Section(header: Text("# of Rolls")) {
                TextField("1", text: $rollCountText)
                    .keyboardType(.numberPad)
            }

            // Dates section: only shown if any date is non-nil
            if dateLoaded != nil || dateFinished != nil || dateScanned != nil {
                Section(header: Text("Dates")) {
                    if dateLoaded != nil {
                        DatePicker(
                            "Loaded",
                            selection: Binding(
                                get: { dateLoaded ?? Date() },
                                set: { dateLoaded = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                    if dateFinished != nil {
                        DatePicker(
                            "Finished",
                            selection: Binding(
                                get: { dateFinished ?? Date() },
                                set: { dateFinished = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                    if dateScanned != nil {
                        DatePicker(
                            "Scanned",
                            selection: Binding(
                                get: { dateScanned ?? Date() },
                                set: { dateScanned = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
            }
        }
        .onAppear {
            // Ensure camera is valid against current cameraNames
            if filmStore.cameraNames.isEmpty == false {
                if !filmStore.cameraNames.contains(camera) {
                    camera = filmStore.cameraNames.first ?? "No camera"
                }
            } else {
                camera = "No camera"
            }

            // Compute stack size for this identity
            let identity = FilmIdentity(
                manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                stock: stock.trimmingCharacters(in: .whitespacesAndNewlines),
                filmType: filmType,
                format: format,
                boxISO: boxISO
            )
            let currentCount = filmStore.rolls.filter { $0.filmIdentity == identity }.count
            rollCountText = String(max(1, currentCount))
        }
        .navigationTitle("Edit Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onComplete(nil) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveEdits()
                }
            }
        }
    }

    private func saveEdits() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStock = stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCamera = camera.trimmingCharacters(in: .whitespacesAndNewlines)

        let updated = FilmRoll(
            id: roll.id,
            notes: trimmedNotes,
            manufacturer: trimmedManufacturer,
            stock: trimmedStock,
            filmType: filmType,
            format: format,
            boxISO: boxISO,
            effectiveISO: effectiveISO,
            camera: trimmedCamera,
            status: roll.status,
            dateCreated: roll.dateCreated,   // preserve original creation date
            dateLoaded: dateLoaded,
            dateFinished: dateFinished,
            dateScanned: dateScanned
        )

        filmStore.updateRoll(updated)

        // Stack size adjustments
        let identity = updated.filmIdentity
        let allRollsForIdentity = filmStore.rolls.filter { $0.filmIdentity == identity }
        let currentCount = allRollsForIdentity.count

        let requested = Int(rollCountText) ?? currentCount
        let targetCount = max(1, requested)

        if targetCount > currentCount {
            let extra = targetCount - currentCount
            for _ in 0..<extra {
                let newRoll = FilmRoll(
                    notes: updated.notes,
                    manufacturer: updated.manufacturer,
                    stock: updated.stock,
                    filmType: updated.filmType,
                    format: updated.format,
                    boxISO: updated.boxISO,
                    effectiveISO: updated.effectiveISO,
                    camera: "No camera",
                    status: .inStorage
                )
                filmStore.addRoll(newRoll)
            }
        } else if targetCount < currentCount {
            let needed = currentCount - targetCount
            if needed > 0 {
                let candidates = filmStore.rolls.filter {
                    $0.filmIdentity == identity && $0.id != updated.id
                }
                let inStorage = candidates.filter { $0.status == .inStorage }
                let toRemove = Array(inStorage.prefix(needed))
                for r in toRemove {
                    filmStore.removeRoll(r)
                }
            }
        }

        onComplete(nil)
    }
}
