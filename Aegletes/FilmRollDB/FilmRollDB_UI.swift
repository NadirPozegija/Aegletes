//
// FilmRollDB_UI.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/7/26.
// Edited on 3/8/26 - Custom top bar, Manage Cameras, bulk # of Rolls create/update, stacked film UI
//

import SwiftUI

// Use FilmIdentity (from FilmRollDatabase.swift) as an identifiable key for stacks
extension FilmIdentity: Identifiable {
    var id: String {
        "\(manufacturer)|\(stock)|\(filmType.rawValue)|\(format.rawValue)|\(boxISO)"
    }
}

struct FilmDBRootView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    /// Callback to return to the meter screen (set by RootView).
    let onBackToMeter: () -> Void

    @State private var showingNewRoll = false
    @State private var showingManageCameras = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom top bar with three aligned buttons
                HStack {
                    // Left: back to meter
                    Button(action: onBackToMeter) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Meter")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 19)
                                .fill(Color.gray.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 19)
                                .stroke(Color.gray.opacity(0.75), lineWidth: 1.5)
                        )
                    }

                    Spacer()

                    // Center: Manage Cameras
                    Button(action: { showingManageCameras = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.badge.plus")
                            Text("Manage Cameras")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 19)
                                .fill(Color.gray.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 19)
                                .stroke(Color.gray.opacity(0.75), lineWidth: 1.5)
                        )
                    }

                    Spacer()

                    // Right: Add Roll
                    Button(action: { showingNewRoll = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "film.roll.plus")
                            Text("Add Roll")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 19)
                                .fill(Color.gray.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 19)
                                .stroke(Color.gray.opacity(0.75), lineWidth: 1.5)
                        )
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground).opacity(0.95))

                Divider()

                // Main content: film stacks list
                FilmStackListView()
            }
            .navigationBarHidden(true)
        }
        // Sheet for adding a new roll (bulk via # of Rolls)
        .sheet(isPresented: $showingNewRoll) {
            NavigationStack {
                FilmRollEditorView { _ in
                    showingNewRoll = false
                }
                .environmentObject(filmStore)
            }
        }
        // Sheet for managing cameras (add + delete)
        .sheet(isPresented: $showingManageCameras) {
            NavigationStack {
                ManageCamerasView()
                    .environmentObject(filmStore)
            }
        }
    }

    // MARK: - Film Stack model (for UI)

    struct FilmStack {
        let identity: FilmIdentity
        let rolls: [FilmRoll]
    }

    // MARK: - Stacked List View

    struct FilmStackListView: View {
        @EnvironmentObject var filmStore: FilmRollStore

        var body: some View {
            List {
                let stacks = buildStacks(from: filmStore.rolls)

                if stacks.isEmpty {
                    Section {
                        Text("No rolls yet. Use Add Roll to create your first entry.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(stacks, id: \.identity.id) { stack in
                        NavigationLink(destination: FilmStackDetailView(identity: stack.identity)) {
                            VStack(alignment: .leading, spacing: 2) {
                                // Title: Manufacturer + Stock
                                Text(heading(for: stack.identity))
                                    .font(.headline)

                                // Subtitle: film type, format, ISO + counts / status
                                Text(subheading(for: stack.identity, rolls: stack.rolls))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }

        private func buildStacks(from rolls: [FilmRoll]) -> [FilmStack] {
            var dict: [FilmIdentity: [FilmRoll]] = [:]
            for roll in rolls {
                dict[roll.filmIdentity, default: []].append(roll)
            }

            // Sort stacks by manufacturer, then stock, then format, then boxISO
            return dict.map { FilmStack(identity: $0.key, rolls: $0.value) }
                .sorted { a, b in
                    let ia = a.identity
                    let ib = b.identity
                    if ia.manufacturer != ib.manufacturer {
                        return ia.manufacturer < ib.manufacturer
                    }
                    if ia.stock != ib.stock {
                        return ia.stock < ib.stock
                    }
                    if ia.filmType != ib.filmType {
                        return ia.filmType.rawValue < ib.filmType.rawValue
                    }
                    if ia.format != ib.format {
                        return ia.format.rawValue < ib.format.rawValue
                    }
                    return ia.boxISO < ib.boxISO
                }
        }

        private func heading(for identity: FilmIdentity) -> String {
            let m = identity.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let s = identity.stock.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = [m, s].filter { !$0.isEmpty }
            if components.isEmpty {
                return "Film Roll"
            }
            return components.joined(separator: " ")
        }

        private func subheading(for identity: FilmIdentity, rolls: [FilmRoll]) -> String {
            var parts: [String] = [
                identity.filmType.rawValue,
                identity.format.rawValue,
                "ISO \(Int(identity.boxISO))"
            ]

            let total = rolls.count
            parts.append("• \(total) roll\(total == 1 ? "" : "s")")

            // Status breakdown
            let inStorage = rolls.filter { $0.status == .inStorage }.count
            let loaded = rolls.filter { $0.status == .loaded }.count
            let finishedLike = rolls.filter { $0.status == .finished || $0.status == .developed || $0.status == .scanning || $0.status == .archived }.count

            var statusParts: [String] = []
            if inStorage > 0 {
                statusParts.append("\(inStorage) in storage")
            }
            if loaded > 0 {
                statusParts.append("\(loaded) loaded")
            }
            if finishedLike > 0 {
                statusParts.append("\(finishedLike) finished/dev")
            }

            if !statusParts.isEmpty {
                parts.append("• " + statusParts.joined(separator: ", "))
            }

            return parts.joined(separator: " ")
        }
    }

    // MARK: - Film Stack Detail (drill into rolls of same film)

    struct FilmStackDetailView: View {
        @EnvironmentObject var filmStore: FilmRollStore
        let identity: FilmIdentity

        var body: some View {
            let rolls = filmStore.rolls.filter { $0.filmIdentity == identity }

            Form {
                Section(header: Text("Film")) {
                    Text("Manufacturer: \(identity.manufacturer)")
                    Text("Stock: \(identity.stock)")
                    Text("Type: \(identity.filmType.rawValue)")
                    Text("Format: \(identity.format.rawValue)")
                    Text("Box ISO: \(Int(identity.boxISO))")
                }

                Section(header: Text("Rolls")) {
                    if rolls.isEmpty {
                        Text("No rolls for this film identity.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(rolls) { roll in
                            NavigationLink(destination: FilmRollDetailView(roll: roll)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Roll \(roll.id.uuidString.prefix(6))")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Status: \(roll.status.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(identity.manufacturer) \(identity.stock)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Detail View (single roll, with Edit & optional Notes)

    struct FilmRollDetailView: View {
        @EnvironmentObject var filmStore: FilmRollStore
        let roll: FilmRoll

        @State private var showingEdit = false

        var body: some View {
            Form {
                // Optional Notes section
                if !roll.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section(header: Text("Notes")) {
                        Text(roll.notes)
                    }
                }

                Section(header: Text("Film")) {
                    Text("Manufacturer: \(roll.manufacturer)")
                    Text("Stock: \(roll.stock)")
                    Text("Type: \(roll.filmType.rawValue)")
                    Text("Format: \(roll.format.rawValue)")
                    Text("Box ISO: \(Int(roll.boxISO))")
                    Text("Effective ISO: \(Int(roll.effectiveISO))")
                }

                Section(header: Text("Camera")) {
                    Text("\(roll.camera)")
                }

                Section(header: Text("Status")) {
                    Text("Status: \(roll.status.rawValue)")
                    if let loaded = roll.dateLoaded {
                        Text("Loaded: \(loaded.formatted(date: .abbreviated, time: .shortened))")
                    }
                    if let finished = roll.dateFinished {
                        Text("Finished: \(finished.formatted(date: .abbreviated, time: .shortened))")
                    }
                    if let scanned = roll.dateScanned {
                        Text("Scanned: \(scanned.formatted(date: .abbreviated, time: .shortened))")
                    }
                }
            }
            .navigationTitle(title(for: roll))
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
                    FilmRollEditView(roll: roll) { _ in
                        showingEdit = false
                    }
                    .environmentObject(filmStore)
                }
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
    }

    // MARK: - Editor View (for creating new rolls, bulk via # of Rolls)

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

                    // Manufacturer: picker + custom text
                    Picker("Manufacturer", selection: $manufacturer) {
                        ForEach(FilmRollDatabase.manufacturerOptions, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    TextField("Custom manufacturer", text: $manufacturer)

                    // Stock: suggestions + custom text
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

    // MARK: - Edit View (for editing a roll + stack count)

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
        }

        var body: some View {
            Form {
                Section(header: Text("Film")) {
                    TextField("Notes", text: $notes, axis: .vertical)

                    // Manufacturer: picker + custom text
                    Picker("Manufacturer", selection: $manufacturer) {
                        ForEach(FilmRollDatabase.manufacturerOptions, id: \.self) { m in
                            Text(m).tag(m)
                        }
                    }
                    TextField("Custom manufacturer", text: $manufacturer)

                    // Stock: suggestions + custom text
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
            .onAppear {
                // Ensure camera is valid, even though hidden in UI
                if filmStore.cameraNames.isEmpty == false {
                    if !filmStore.cameraNames.contains(camera) {
                        camera = filmStore.cameraNames.first ?? "No camera"
                    }
                } else {
                    camera = "No camera"
                }

                // Initialize # of Rolls from current group count
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

            // 1) Update this roll
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
                dateLoaded: roll.dateLoaded,
                dateFinished: roll.dateFinished,
                dateScanned: roll.dateScanned
            )
            filmStore.updateRoll(updated)

            // 2) Adjust group size (same film identity)
            let identity = updated.filmIdentity

            let allRollsForIdentity = filmStore.rolls.filter { $0.filmIdentity == identity }
            let currentCount = allRollsForIdentity.count
            let requested = Int(rollCountText) ?? currentCount
            let targetCount = max(1, requested)

            if targetCount > currentCount {
                // Need to add extra rolls
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
                // Need to remove some rolls (prefer inStorage, never delete the edited roll)
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

    // MARK: - Manage Cameras View (add + delete with warning, hide "No camera")

    struct ManageCamerasView: View {
        @EnvironmentObject var filmStore: FilmRollStore
        @Environment(\.dismiss) private var dismiss

        @State private var newCameraName: String = ""
        @State private var cameraPendingDelete: String?
        @State private var pendingDeleteCount: Int = 0
        @State private var showingDeleteAlert: Bool = false

        var body: some View {
            // Only show user-defined cameras, hide "No camera" from the list
            let visibleCameras = filmStore.cameraNames.filter { $0 != "No camera" }

            List {
                Section(header: Text("Cameras")) {
                    ForEach(visibleCameras, id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { offsets in
                        handleDelete(at: offsets, from: visibleCameras)
                    }
                }

                Section(header: Text("Add Camera")) {
                    TextField("e.g. Nikon FM2", text: $newCameraName)
                    Button("Save") {
                        addCamera()
                    }
                }
            }
            .navigationTitle("Manage Cameras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Camera?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let name = cameraPendingDelete {
                        filmStore.removeCameraName(name)
                    }
                    cameraPendingDelete = nil
                    pendingDeleteCount = 0
                }
                Button("Cancel", role: .cancel) {
                    cameraPendingDelete = nil
                    pendingDeleteCount = 0
                }
            } message: {
                if let name = cameraPendingDelete {
                    if pendingDeleteCount > 0 {
                        Text(
                            "The camera \"\(name)\" is currently assigned to \(pendingDeleteCount) roll\(pendingDeleteCount == 1 ? "" : "s") of film. Deleting it will set those rolls to \"No camera\"."
                        )
                    } else {
                        Text("This will remove \"\(name)\" from your camera list.")
                    }
                } else {
                    Text("This will remove the selected camera from your list.")
                }
            }
        }

        private func addCamera() {
            let trimmed = newCameraName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard trimmed != "No camera" else { return } // reserve default name
            guard !filmStore.cameraNames.contains(trimmed) else {
                newCameraName = ""
                return
            }
            filmStore.addCameraName(trimmed)
            newCameraName = ""
        }

        private func handleDelete(at offsets: IndexSet, from visibleCameras: [String]) {
            for index in offsets {
                guard index < visibleCameras.count else { continue }
                let name = visibleCameras[index]
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                // Count how many rolls currently use this camera
                let count = filmStore.rolls.filter {
                    $0.camera.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed
                }.count

                cameraPendingDelete = trimmed
                pendingDeleteCount = count
                showingDeleteAlert = true
            }
        }
    }
}
