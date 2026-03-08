//
// FilmRollDB_UI.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/7/26.
// Edited on 3/8/26 - Custom top bar, Manage Cameras, bulk # of Rolls create/update, HeroView stacks with ZStack
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

                // Main content: film stacks list with HeroView for multi-roll stacks
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

    // MARK: - Stacked List View (HeroView expand/collapse for multi-roll stacks)

    struct FilmStackListView: View {
        @EnvironmentObject var filmStore: FilmRollStore

        @State private var expandedStackIDs: Set<FilmIdentity.ID> = []
        @State private var rollBeingEdited: FilmRoll?
        @State private var showingEditSheet: Bool = false

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
                        if stack.rolls.count > 1 {
                            // Multi-roll: HeroView that expands/collapses to show entries
                            Section {
                                // Hero row (ZStack), with a single swipe action to delete the entire stack
                                FilmStackHeroView(
                                    identity: stack.identity,
                                    rolls: stack.rolls,
                                    isExpanded: expandedStackIDs.contains(stack.identity.id)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if expandedStackIDs.contains(stack.identity.id) {
                                        expandedStackIDs.remove(stack.identity.id)
                                    } else {
                                        expandedStackIDs.insert(stack.identity.id)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        // Delete the entire stack (all rolls of this identity)
                                        expandedStackIDs.remove(stack.identity.id)
                                        let all = filmStore.rolls.filter { $0.filmIdentity == stack.identity }
                                        all.forEach { filmStore.removeRoll($0) }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }

                                // Expanded entries, sequentially named, each with its own swipe action
                                if expandedStackIDs.contains(stack.identity.id) {
                                    ForEach(Array(stack.rolls.enumerated()), id: \.element.id) { index, roll in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Roll \(index + 1)")
                                                    .font(.subheadline.weight(.semibold))
                                                rollSubheadline(for: roll)
                                            }
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            rollBeingEdited = roll
                                            showingEditSheet = true
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                filmStore.removeRoll(roll)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        } else if let roll = stack.rolls.first {
                            // Single roll: normal row that goes straight to detail
                            NavigationLink(destination: FilmRollDetailView(roll: roll)) {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(heading(for: stack.identity))
                                            .font(.headline)

                                        rollSubheadline(for: roll)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: {
                rollBeingEdited = nil
            }) {
                if let roll = rollBeingEdited {
                    NavigationStack {
                        FilmRollEditView(roll: roll) { _ in
                            showingEditSheet = false
                        }
                        .environmentObject(filmStore)
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

        // MARK: - Subheadline builder with SF Symbols

        @ViewBuilder
        private func rollSubheadline(for roll: FilmRoll) -> some View {
            HStack(spacing: 4) {
                // Format
                Text(roll.format.rawValue)

                Text("•")

                // Film Type + icon (rainbow for Color, square.tophalf.filled for B&W)
                HStack(spacing: 2) {
                    Text(roll.filmType.rawValue)
                    switch roll.filmType {
                    case .color:
                        Image(systemName: "rainbow")
                    case .bw:
                        Image(systemName: "square.tophalf.filled")
                    case .slide:
                        EmptyView() // no specific icon defined
                    }
                }

                Text("•")

                // ISO (Box ISO)
                Text("ISO \(Int(roll.boxISO))")

                Text("•")

                // Status + icon
                HStack(spacing: 2) {
                    Text(roll.status.rawValue)
                    if let statusSymbol = statusSymbolName(for: roll.status) {
                        Image(systemName: statusSymbol)
                    }
                }

                // Optional camera + icon
                let cam = roll.camera.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cam.isEmpty {
                    Text("•")
                    HStack(spacing: 2) {
                        Text(cam)
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        private func statusSymbolName(for status: FilmRollStatus) -> String? {
            switch status {
            case .inStorage:
                return "shippingbox.fill"
            case .loaded:
                return "camera.circle.fill"
            case .finished:
                return "flag.checkered"      // closest to "finish flag"
            case .developed:
                return "testtube.2"
            case .scanning:
                return "testtube.2"          // treat as in-process, same as developed
            case .archived:
                return "film.stack"
            }
        }
    }

    // MARK: - Film Stack HeroView (for multi-roll stacks, ZStack of row previews)

    struct FilmStackHeroView: View {
        let identity: FilmIdentity
        let rolls: [FilmRoll]
        let isExpanded: Bool

        var body: some View {
            let displayCount = min(rolls.count, 3)

            ZStack(alignment: .topLeading) {
                ForEach(0..<displayCount, id: \.self) { index in
                    heroRow(showText: index == displayCount - 1)
                        .offset(y: CGFloat(index * 4))
                        .opacity(index == displayCount - 1 ? 1.0 : 0.85)
                }
            }
        }

        private func heroRow(showText: Bool) -> some View {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))

                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)

                if showText {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            // Title (based on film identity)
                            Text(heroTitle)
                                .font(.headline)

                            // Subtitle
                            Text(heroSubtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text("×\(rolls.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }

        private var heroTitle: String {
            let m = identity.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let s = identity.stock.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = [m, s].filter { !$0.isEmpty }
            if components.isEmpty {
                return "Film Roll"
            }
            return components.joined(separator: " ")
        }

        private var heroSubtitle: String {
            var parts: [String] = [
                identity.format.rawValue,
                identity.filmType.rawValue,
                "ISO \(Int(identity.boxISO))"
            ]

            let total = rolls.count
            parts.append("• \(total) roll\(total == 1 ? "" : "s")")

            let inStorage = rolls.filter { $0.status == .inStorage }.count
            let loaded = rolls.filter { $0.status == .loaded }.count
            let finishedLike = rolls.filter {
                $0.status == .finished || $0.status == .developed || $0.status == .scanning || $0.status == .archived
            }.count

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

            return parts.joined(separator: " • ")
        }
    }

    // MARK: - Film Stack Detail (still available via navigation if needed)

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
            .onAppear {
                if filmStore.cameraNames.isEmpty == false {
                    if !filmStore.cameraNames.contains(camera) {
                        camera = filmStore.cameraNames.first ?? "No camera"
                    }
                } else {
                    camera = "No camera"
                }

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
                dateLoaded: roll.dateLoaded,
                dateFinished: roll.dateFinished,
                dateScanned: roll.dateScanned
            )
            filmStore.updateRoll(updated)

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

    // MARK: - Manage Cameras View (add + delete with warning, hide "No camera")

    struct ManageCamerasView: View {
        @EnvironmentObject var filmStore: FilmRollStore
        @Environment(\.dismiss) private var dismiss

        @State private var newCameraName: String = ""
        @State private var cameraPendingDelete: String?
        @State private var pendingDeleteCount: Int = 0
        @State private var showingDeleteAlert: Bool = false

        var body: some View {
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
            guard trimmed != "No camera" else { return }
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
