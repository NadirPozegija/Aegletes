//
// FilmRollDetailAndEditViews.swift
// Aegletes
//
// Detail view, New Roll editor, Edit Roll editor (+ stack size logic)
//
// Edited on 3/9/26 - Revision 3 - Status dates in detail, editable dates in edit view,
// and bottom "Update Status" button reusing FilmRollStore.updateStatus/loadRoll.
//

import SwiftUI

struct FilmRollDetailView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    let roll: FilmRoll
    @State private var showingEdit = false

    // Local status workflow state (UI only; backend logic is in FilmRollStore)
    @State private var pendingNextStatus: FilmRollStatus?
    @State private var showingStatusAlert = false

    @State private var showingLoadSheet = false
    @State private var selectedCameraForLoad: String = ""
    @State private var selectedEffectiveISOForLoad: Double = FilmRollDatabase.effectiveISOOptions.first ?? 100

    /// Always use the latest copy of this roll from the store (so dates/status stay in sync).
    private var liveRoll: FilmRoll {
        filmStore.rolls.first(where: { $0.id == roll.id }) ?? roll
    }

    var body: some View {
        Form {
            if !liveRoll.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section(header: Text("Notes")) {
                    Text(liveRoll.notes)
                }
            }

            Section(header: Text("Film")) {
                Text("Manufacturer: \(liveRoll.manufacturer)")
                Text("Stock: \(liveRoll.stock)")
                Text("Type: \(liveRoll.filmType.rawValue)")
                Text("Format: \(liveRoll.format.rawValue)")
                Text("Box ISO: \(Int(liveRoll.boxISO))")
                Text("Effective ISO: \(Int(liveRoll.effectiveISO))")
            }

            Section(header: Text("Camera")) {
                Text(liveRoll.camera)
            }

            Section(header: Text("Status")) {
                Text("\(liveRoll.status.rawValue)").bold()
                if let loaded = liveRoll.dateLoaded {
                    Text("Loaded: \(loaded.formatted(date: .abbreviated, time: .shortened))")
                }
                if let finished = liveRoll.dateFinished {
                    Text("Finished: \(finished.formatted(date: .abbreviated, time: .shortened))")
                }
                if let scanned = liveRoll.dateScanned {
                    Text("Scanned: \(scanned.formatted(date: .abbreviated, time: .shortened))")
                }
            }

            // Bottom "Update Status" button (mirrors swipe action behavior)
            Section {
                Button {
                    handleUpdateStatusTap()
                } label: {
                    HStack {
                        Spacer()
                        Text("Update Status")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(title(for: liveRoll))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                FilmRollEditView(roll: liveRoll) { _ in
                    showingEdit = false
                }
                .environmentObject(filmStore)
            }
        }
        // Load Roll sheet (same view as list, but driven by detail state)
        .sheet(isPresented: $showingLoadSheet) {
            NavigationStack {
                LoadRollStatusView(
                    roll: liveRoll,
                    cameraNames: filmStore.cameraNames.filter { $0 != "No camera" },
                    selectedCamera: $selectedCameraForLoad,
                    selectedISO: $selectedEffectiveISOForLoad
                ) { confirmed in
                    if confirmed {
                        filmStore.loadRoll(
                            id: liveRoll.id,
                            camera: selectedCameraForLoad,
                            effectiveISO: selectedEffectiveISOForLoad
                        )
                    }
                    showingLoadSheet = false
                }
            }
        }
        // Confirmation alert for non-loaded status changes
        .alert("Update Status", isPresented: $showingStatusAlert) {
            Button("Cancel", role: .cancel) {
                pendingNextStatus = nil
            }
            Button("Confirm") {
                if let next = pendingNextStatus {
                    filmStore.updateStatus(forRollId: liveRoll.id, to: next)
                }
                pendingNextStatus = nil
            }
        } message: {
            Text(statusAlertMessage(for: pendingNextStatus))
        }
    }

    private func title(for roll: FilmRoll) -> String {
        let m = roll.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = roll.stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = [m, s].filter { !$0.isEmpty }
        if components.isEmpty {
            return "Film Roll"
        }
        return components.joined(separator: " ")
    }

    // MARK: - Status helpers (reuse same progression as list)

    private func nextStatus(after status: FilmRollStatus) -> FilmRollStatus? {
        switch status {
        case .inStorage:
            return .loaded
        case .loaded:
            return .finished
        case .finished:
            return .developed
        case .developed:
            return .scanning
        case .scanning:
            return .archived
        case .archived:
            return .scanning
        }
    }

    private func handleUpdateStatusTap() {
        guard let next = nextStatus(after: liveRoll.status) else { return }

        if next == .loaded {
            prepareLoadDefaults()
            showingLoadSheet = true
        } else {
            pendingNextStatus = next
            showingStatusAlert = true
        }
    }

    private func statusAlertMessage(for next: FilmRollStatus?) -> String {
        guard let next else { return "" }
        switch next {
        case .inStorage:
            return "Return this roll to storage?"
        case .loaded:
            return "Load this roll into a camera?"
        case .finished:
            return "Mark this roll as Finished?"
        case .developed:
            return "Mark this roll as Developed?"
        case .scanning:
            return "Mark this roll as Scanning?"
        case .archived:
            return "Archive this roll?"
        }
    }

    private func prepareLoadDefaults() {
        // Do NOT pre-fill a camera; force the user to pick/enter one.
        selectedCameraForLoad = ""

        // Default effective ISO: effectiveISO if valid, else boxISO, else first option
        let defaultISO = (liveRoll.effectiveISO > 0) ? liveRoll.effectiveISO : liveRoll.boxISO
        if FilmRollDatabase.effectiveISOOptions.contains(defaultISO) {
            selectedEffectiveISOForLoad = defaultISO
        } else {
            selectedEffectiveISOForLoad = FilmRollDatabase.effectiveISOOptions.first ?? defaultISO
        }
    }
}

// MARK: - New / Edit Views (unchanged except for dates)

struct FilmRollEditorView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    let onComplete: (FilmRoll?) -> Void

    @State private var notes: String = ""
    @State private var manufacturer: String = FilmRollDatabase.manufacturerOptions.first ?? ""
    @State private var stock: String = ""
    @State private var filmType: FilmType = .color
    @State private var format: FilmFormat = .thirtyFive
    @State private var boxISO: Double = FilmRollDatabase.boxISOOptions.first ?? 100
    @State private var rollCountText: String = "1"

    var body: some View {
        Form {
            Section(header: Text("Film")) {
                TextField("Notes", text: $notes, axis: .vertical)

                Picker("Manufacturer", selection: $manufacturer) {
                    ForEach(FilmRollDatabase.manufacturerOptions, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }

                TextField("Custom manufacturer", text: $manufacturer)

                if let stocks = FilmRollDatabase.stockCatalog[manufacturer], !stocks.isEmpty {
                    Picker("Stock", selection: $stock) {
                        ForEach(stocks, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                }

                TextField("Custom stock", text: $stock)

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
        }
        .navigationTitle("New Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onComplete(nil) }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveRolls()
                }
            }
        }
    }

    private func saveRolls() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStock = stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedCount = Int(rollCountText) ?? 1
        let count = max(1, requestedCount)

        for _ in 0..<count {
            let roll = FilmRoll(
                notes: trimmedNotes,
                manufacturer: trimmedManufacturer,
                stock: trimmedStock,
                filmType: filmType,
                format: format,
                boxISO: boxISO,
                effectiveISO: boxISO,   // default EI = box ISO
                camera: "No camera",
                status: .inStorage
            )
            filmStore.addRoll(roll)
        }

        onComplete(nil)
    }
}

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

                TextField("Custom manufacturer", text: $manufacturer)

                if let stocks = FilmRollDatabase.stockCatalog[manufacturer], !stocks.isEmpty {
                    Picker("Stock", selection: $stock) {
                        ForEach(stocks, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                }

                TextField("Custom stock", text: $stock)

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
