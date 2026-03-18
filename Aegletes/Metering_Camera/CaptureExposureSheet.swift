////  CaptureExposureSheet.swift
//   Aegletes
////
////  Half-sheet UI to capture an exposure against a loaded roll.
//

import SwiftUI

struct CaptureExposureSheet: View {
    /// Rolls that are currently loaded; caller filters these.
    let loadedRolls: [FilmRoll]

    /// Controls sheet dismissal.
    @Binding var isPresented: Bool

    /// Called when the user hits Save with valid input.
    /// You get the chosen roll, frame number, and notes.
    let onSave: (FilmRoll, Int, String) -> Void

    @State private var selectedRollId: UUID?
    @State private var selectedFrame: Int = 1
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if loadedRolls.isEmpty {
                    Text("No loaded rolls available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Text("Load a roll in the Film DB to save exposure notes here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                } else {
                    // Roll picker inline with label
                    HStack {
                        Text("Roll")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Picker("", selection: $selectedRollId) {
                            ForEach(loadedRolls) { roll in
                                Text(rollTitle(roll))
                                    .tag(Optional(roll.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.navigationLink)
                        .frame(width: 260)    // tweak as desired
                    }
                    .onAppear {
                        if selectedRollId == nil {
                            selectedRollId = loadedRolls.first?.id
                        }
                    }
                    
                    Divider()

                    // Frame picker (1–36) inline with label
                    HStack {
                        Text("Frame")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()

                        Picker("", selection: $selectedFrame) {
                            ForEach(1...36, id: \.self) { frame in
                                Text("\(frame)").tag(frame)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(width: 140, height: 160)   // tweak width/height as needed
                    }
                    
                    Divider()

                    // Scene Notes Section
                    HStack{
                        Text("Scene Notes")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Spacer()
                        
                        // Notes field
                        TextField("e.g. Skyline at dawn", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard
                            let id = selectedRollId,
                            let roll = loadedRolls.first(where: { $0.id == id })
                        else {
                            return
                        }
                        onSave(roll, selectedFrame, notes)
                        isPresented = false
                    }
                    .disabled(loadedRolls.isEmpty || selectedRollId == nil)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func rollTitle(_ roll: FilmRoll) -> String {
        let m = roll.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = roll.stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = [m, s].filter { !$0.isEmpty }.joined(separator: " ")
        return label.isEmpty ? "Film Roll" : label
    }
}
