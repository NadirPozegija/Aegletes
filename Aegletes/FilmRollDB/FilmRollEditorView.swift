//
//  FilmRollEditorView.swift
//  Aegletes
//
//  New roll editor (create one or multiple rolls for a given identity).
//

import SwiftUI

struct FilmRollEditorView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    let onComplete: (FilmRoll?) -> Void

    @State private var notes: String = ""
    @State private var manufacturer: String = "" //start empty
    @State private var stock: String = ""
    @State private var filmType: FilmType? = nil
    @State private var format: FilmFormat = .thirtyFive
    @State private var boxISO: Double = FilmRollDatabase.boxISOOptions.first ?? 100
    @State private var rollCountText: String = "1"

    var body: some View {
        Form {
            Section(header: Text("Film")) {
                TextField("Notes", text: $notes, axis: .vertical)

                Picker("Manufacturer", selection: $manufacturer) {
                    Text("Select a Manufacturer").tag("")
                        ForEach(FilmRollDatabase.manufacturerOptions, id: \.self) { m in
                            Text(m).tag(m).bold().italic()
                    }
                }

                TextField("Or, enter custom manufacturer", text: $manufacturer)

                if let stocks = FilmRollDatabase.stockCatalog[manufacturer], !stocks.isEmpty {
                    Picker("Stock", selection: $stock) {
                        ForEach(stocks, id: \.self) { s in
                            Text(s).tag(s).bold().italic()
                        }
                    }
                }

                TextField("Or, enter custom stock", text: $stock)

                Picker("Film Type", selection: $filmType) {
                    Text("Color/B&W/Slide").tag(FilmType?.none)
                    ForEach(FilmRollDatabase.filmTypeOptions) { t in
                        Text(t.rawValue).tag(Optional(t))
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
        
        // If user never picks a film type, default to .color
        let effectiveFilmType = filmType ?? .color

        let requestedCount = Int(rollCountText) ?? 1
        let count = max(1, requestedCount)

        for _ in 0..<count {
            let roll = FilmRoll(
                notes: trimmedNotes,
                manufacturer: trimmedManufacturer,
                stock: trimmedStock,
                filmType: effectiveFilmType,
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
