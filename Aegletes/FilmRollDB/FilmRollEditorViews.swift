//
//  FilmRollEditorViews.swift
//  Aegletes
//
//  Combined New Roll and Edit Roll views, with shared stock defaults behavior.
//

import SwiftUI

// MARK: - New Roll Editor

struct FilmRollEditorView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    let onComplete: (FilmRoll?) -> Void

    @State private var notes: String = ""
    @State private var manufacturer: String = ""
    @State private var stock: String = ""
    @State private var filmType: FilmType? = nil
    @State private var format: FilmFormat = .thirtyFive
    @State private var boxISO: Double = FilmRollDatabase.boxISOOptions.first ?? 100
    @State private var rollCountText: String = "1"

    var body: some View {
        Form {
            Section(header: Text("Film").font(.title)) {
                TextField("Notes", text: $notes, axis: .vertical)

                // Manufacturer picker
                Picker("Manufacturer", selection: $manufacturer) {
                    // Only real manufacturers in the list
                    ForEach(FilmRollDatabase.manufacturerOptions, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .onChange(of: manufacturer) {
                    applyKnownStockDefaults()
                }
                .overlay(alignment: .trailing) {
                    // Sentinel text when there is no manufacturer yet
                    if manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Select a Manufacturer")
                            .foregroundColor(.secondary)
                            .allowsHitTesting(false)
                            .padding(.trailing, 12)
                    }
                }

                // Custom manufacturer
                TextField("Or enter custom manufacturer", text: $manufacturer)
                    .bold()
                    .italic()
                    .onChange(of: manufacturer) {
                        applyKnownStockDefaults()
                    }

                // Stock picker for selected manufacturer
                if let stocks = FilmRollDatabase.stockCatalog[manufacturer], !stocks.isEmpty {
                    Picker("Stock", selection: $stock) {
                        // Only real stocks in the list
                        ForEach(stocks, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .onChange(of: stock) {
                        applyKnownStockDefaults()
                    }
                    .overlay(alignment: .trailing) {
                        if stock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Select a Stock")
                                .foregroundColor(.secondary)
                                .allowsHitTesting(false)
                                .padding(.trailing, 12)
                        }
                    }
                }

                // Custom stock
                TextField("Or enter custom stock", text: $stock)
                    .bold()
                    .italic()
                    .onChange(of: stock) {
                        applyKnownStockDefaults()
                    }

                // Film type – will be auto-filled when possible
                Picker(selection: $filmType, label: Text(filmType?.rawValue ?? "Color/B&W/Slide")
                ) {
                    // Only real options in the list
                    ForEach(FilmRollDatabase.filmTypeOptions) { t in
                        Text(t.rawValue).tag(Optional(t))
                    }
                }

                // Format
                Picker("Format", selection: $format) {
                    ForEach(FilmRollDatabase.formatOptions) { f in
                        Text(f.rawValue).tag(f)
                    }
                }

                // Box ISO – jumps when defaults apply
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
        }
        .navigationTitle("New Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onComplete(nil) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveRolls() }
            }
        }
    }

    // MARK: - Known stock defaults (New Roll)

    private func applyKnownStockDefaults() {
        guard let (type, iso) = FilmRollDatabase.stockDefaults(
            forManufacturer: manufacturer,
            stock: stock
        ) else {
            return
        }

        // Always override film type if known
        filmType = type

        // Snap box ISO to canonical speed if available
        if FilmRollDatabase.boxISOOptions.contains(iso) {
            boxISO = iso
        }
    }

    // MARK: - Save (New Roll)

    private func saveRolls() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStock = stock.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedType = filmType ?? .color
        let requestedCount = Int(rollCountText) ?? 1
        let count = max(1, requestedCount)

        for _ in 0..<count {
            let roll = FilmRoll(
                notes: trimmedNotes,
                manufacturer: trimmedManufacturer.isEmpty ? "Unknown" : trimmedManufacturer,
                stock: trimmedStock.isEmpty ? "Unknown" : trimmedStock,
                filmType: resolvedType,
                format: format,
                boxISO: boxISO,
                effectiveISO: boxISO,
                camera: "No camera"
            )
            filmStore.addRoll(roll)
        }

        onComplete(nil)
    }
}

// MARK: - Edit Existing Roll

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

    // Whether this roll is part of a stack (more than one roll with same identity)
    @State private var isPartOfStack: Bool = false
    
    // Whether this roll belonged to a stack at the time the editor opened
    @State private var isPartOfOriginalStack: Bool = false

    // The original identity of this roll when opened (for stack detection)
    @State private var originalIdentity: FilmIdentity

    // For identity-change confirmation
    @State private var pendingUpdatedRoll: FilmRoll?
    @State private var showingIdentityScopeAlert: Bool = false
    
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
        _originalIdentity = State(initialValue: roll.filmIdentity)
    }
    
    private func normalizeCameraIfNeeded() {
        if filmStore.cameraNames.isEmpty == false {
            if !filmStore.cameraNames.contains(camera) {
                camera = filmStore.cameraNames.first ?? "No camera"
            }
        } else {
            camera = "No camera"
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Film")) {
                TextField("Notes", text: $notes, axis: .vertical)

                // Manufacturer picker
                Picker("Manufacturer", selection: $manufacturer) {
                    ForEach(FilmRollDatabase.manufacturerOptions, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .onChange(of: manufacturer) {
                    applyKnownStockDefaults()
                }

                // Custom manufacturer
                TextField("Or enter Custom Manufacturer", text: $manufacturer)
                    .bold()
                    .italic()
                    .onChange(of: manufacturer) {
                        applyKnownStockDefaults()
                    }

                // Stock picker for selected manufacturer
                if let stocks = FilmRollDatabase.stockCatalog[manufacturer], !stocks.isEmpty {
                    Picker("Stock", selection: $stock) {
                        ForEach(stocks, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .onChange(of: stock) {
                        applyKnownStockDefaults()
                    }
                }

                // Custom stock
                TextField("Or enter custom stock", text: $stock)
                    .bold()
                    .italic()
                    .onChange(of: stock) {
                        applyKnownStockDefaults()
                    }

                // Film type – will be updated when defaults apply
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

            // Only show "# of Rolls" section for non-stacked rolls
            if !isPartOfStack {
                Section(header: Text("# of Rolls")) {
                    TextField("1", text: $rollCountText)
                        .keyboardType(.numberPad)
                }
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
            normalizeCameraIfNeeded()

            // 2) How many rolls shared this identity when we opened the editor?
            let originalCount = filmStore.rolls
                .filter { $0.filmIdentity == originalIdentity }
                .count
            isPartOfOriginalStack = originalCount > 1

            // 3) Current identity based on the editable fields
            let currentIdentity = FilmIdentity(
                manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                stock: stock.trimmingCharacters(in: .whitespacesAndNewlines),
                filmType: filmType,
                format: format,
                boxISO: boxISO
            )
            let currentCount = filmStore.rolls
                .filter { $0.filmIdentity == currentIdentity }
                .count

            isPartOfStack = currentCount > 1

            // 4) Initialize rollCountText from current identity
            //    non‑stack rolls get editable count;
            //    stacks are locked and only changed via setStackCount on save)
            rollCountText = String(max(1, currentCount))
        }
        .navigationTitle("Edit Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onComplete(nil) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveEdits() }
            }
        }
        .alert("Apply Changes", isPresented: $showingIdentityScopeAlert) {
            Button("This Roll Only") {
                if let updated = pendingUpdatedRoll {
                    filmStore.updateRoll(updated)
                }
                pendingUpdatedRoll = nil
                onComplete(nil)
            }
            Button("All Rolls in Stack") {
                if let updated = pendingUpdatedRoll {
                    let newIdentity = updated.filmIdentity
                    filmStore.updateIdentityForAllRolls(
                        in: originalIdentity,
                        to: newIdentity
                    )
                }
                pendingUpdatedRoll = nil
                onComplete(nil)
            }
            Button("Cancel", role: .cancel) {
                pendingUpdatedRoll = nil
            }
        } message: {
            Text("Do you want to apply these changes to this roll only, or to this entire stack?")
        }
    }

    // MARK: - Known stock defaults (Edit Roll)

    private func applyKnownStockDefaults() {
        guard let (type, iso) = FilmRollDatabase.stockDefaults(
            forManufacturer: manufacturer,
            stock: stock
        ) else {
            return
        }

        // Always override film type if known
        filmType = type

        if FilmRollDatabase.boxISOOptions.contains(iso) {
            boxISO = iso
        }
    }

    // MARK: - Save (Edit Roll)
    
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
            camera: trimmedCamera.isEmpty ? "No camera" : trimmedCamera,
            status: roll.status,
            dateCreated: roll.dateCreated,
            dateLoaded: dateLoaded,
            dateFinished: dateFinished,
            dateScanned: dateScanned
        )

        let newIdentity = updated.filmIdentity
        let identityChanged = (newIdentity != originalIdentity)

        if identityChanged && isPartOfOriginalStack {
            // Defer decision to alert: this roll vs entire stack
            pendingUpdatedRoll = updated
            showingIdentityScopeAlert = true
            return
        }

        // No stack, or identity unchanged: just update this roll
        filmStore.updateRoll(updated)

        // Only allow editing stack size for non-stacked rolls
        if !isPartOfStack {
            let identity = updated.filmIdentity
            let requested = Int(rollCountText) ?? 1
            let targetCount = max(1, requested)
            filmStore.setStackCount(for: identity, to: targetCount)
        }

        onComplete(nil)
    }
}
