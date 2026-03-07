//
// FilmRollDB_UI.swift
// Aegletes
//
// Created by Nadir Pozegija on 3/7/26.
// Edited on 3/8/26 - Separate Add Camera and + buttons with clear spacing
//

import SwiftUI

struct FilmDBRootView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    /// Callback to return to the meter screen (set by RootView).
    let onBackToMeter: () -> Void
    
    @State private var showingNewRoll = false
    @State private var showingAddCamera = false
    
    var body: some View {
        NavigationStack {
            FilmRollListView()
                .navigationTitle("Film Inventory")
                .toolbar {
                    // Back arrow (top-left) to go back to camera/meter
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onBackToMeter) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Meter")
                            }
                        }
                    }
                }
                .toolbar {
                    //Center - "Add Camera" button
                    ToolbarItem(placement: .principal) {
                        Button(action: { showingAddCamera = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.badge.plus")
                                Text("Add Camera")
                            }
                        }
                    }
                }
                .toolbar {
                    //Right: + button to add a new film roll
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingNewRoll = true }) {
                            Image(systemName: "plus")
                            Text("Roll")
                                .imageScale(.medium)
                        }
                    }
                }
        }
        //sheet for adding a new roll
        .sheet(isPresented: $showingNewRoll) {
            NavigationStack {
                FilmRollEditorView {newRoll in
                    if let newRoll = newRoll {
                        filmStore.addRoll(newRoll)
                    }
                    showingNewRoll = false
                }
                .environmentObject(filmStore)
            }
        }
        //Sheet for adding a new camera
        .sheet(isPresented: $showingAddCamera) {
            NavigationStack {
                AddCameraView { newName in
                    if let newName = newName {
                        filmStore.addCameraName(newName)
                    }
                    showingAddCamera = false
                }
            }
        }
    }
    
    // MARK: - List View
    
    struct FilmRollListView: View {
        @EnvironmentObject var filmStore: FilmRollStore
        
        var body: some View {
            List {
                if filmStore.rolls.isEmpty {
                    Section {
                        Text("No rolls yet. Tap + to add your first roll.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(filmStore.rolls) { roll in
                        NavigationLink(destination: FilmRollDetailView(roll: roll)) {
                            VStack(alignment: .leading, spacing: 2) {
                                // Main heading: Manufacturer + Stock
                                Text(heading(for: roll))
                                    .font(.headline)
                                
                                // Subheading: Film type, format, EI, camera
                                Text(subheading(for: roll))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Status line
                                Text("Status: \(roll.status.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteRolls)
                }
            }
        }
        
        private func deleteRolls(at offsets: IndexSet) {
            for index in offsets {
                let roll = filmStore.rolls[index]
                filmStore.removeRoll(withId: roll.id)
            }
        }
        
        private func heading(for roll: FilmRoll) -> String {
            let m = roll.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
            let s = roll.stock.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = [m, s].filter { !$0.isEmpty }
            if components.isEmpty {
                return "Film Roll"
            }
            return components.joined(separator: " ")
        }
        
        private func subheading(for roll: FilmRoll) -> String {
            var parts: [String] = [
                roll.filmType.rawValue,
                roll.format.rawValue,
                "EI \(Int(roll.effectiveISO))"
            ]
            let cam = roll.camera.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cam.isEmpty {
                parts.append(cam)
            }
            return parts.joined(separator: " • ")
        }
    }
    
    // MARK: - Detail View (with Edit & optional Notes)
    
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
                    Text("Camera: \(roll.camera)")
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
                    FilmRollEditView(roll: roll) { updated in
                        if let updated = updated {
                            filmStore.updateRoll(updated)
                        }
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
    
    // MARK: - Editor View (for creating a new roll)
    
    struct FilmRollEditorView: View {
        @EnvironmentObject var filmStore: FilmRollStore
        let onComplete: (FilmRoll?) -> Void
        
        @State private var notes: String = ""
        @State private var manufacturer: String = FilmRollDatabase.manufacturerOptions.first ?? ""
        @State private var stock: String = ""
        @State private var filmType: FilmType = .color
        @State private var format: FilmFormat = .thirtyFive
        @State private var boxISO: Double = FilmRollDatabase.boxISOOptions.first ?? 100
        @State private var effectiveISO: Double = FilmRollDatabase.effectiveISOOptions.first ?? 100
        @State private var camera: String = "No camera"
        
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
                    
                    Picker("Effective ISO", selection: $effectiveISO) {
                        ForEach(FilmRollDatabase.effectiveISOOptions, id: \.self) { iso in
                            Text("EI \(Int(iso))").tag(iso)
                        }
                    }
                }
                
                Section(header: Text("Camera")) {
                    Picker("Camera", selection: $camera) {
                        ForEach(filmStore.cameraNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
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
            }
            .navigationTitle("New Roll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedManufacturer = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedStock = stock.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedCamera = camera.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let roll = FilmRoll(
                            notes: trimmedNotes,
                            manufacturer: trimmedManufacturer,
                            stock: trimmedStock,
                            filmType: filmType,
                            format: format,
                            boxISO: boxISO,
                            effectiveISO: effectiveISO,
                            camera: trimmedCamera,
                            status: .inStorage
                        )
                        onComplete(roll)
                    }
                }
            }
        }
    }
    
    // MARK: - Edit View (for editing an existing roll)
    
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
                    
                    Picker("Effective ISO", selection: $effectiveISO) {
                        ForEach(FilmRollDatabase.effectiveISOOptions, id: \.self) { iso in
                            Text("EI \(Int(iso))").tag(iso)
                        }
                    }
                }
                
                Section(header: Text("Camera")) {
                    Picker("Camera", selection: $camera) {
                        ForEach(filmStore.cameraNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
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
            }
            .navigationTitle("Edit Roll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
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
                        onComplete(updated)
                    }
                }
            }
        }
    }
    
    // MARK: - Add Camera View
    
    struct AddCameraView: View {
        let onComplete: (String?) -> Void
        
        @State private var cameraName: String = ""
        
        var body: some View {
            Form {
                Section(header: Text("Camera Name")) {
                    TextField("e.g. Nikon FM2", text: $cameraName)
                }
            }
            .navigationTitle("Add Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete(nil) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = cameraName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onComplete(trimmed.isEmpty ? nil : trimmed)
                    }
                }
            }
        }
    }
}
