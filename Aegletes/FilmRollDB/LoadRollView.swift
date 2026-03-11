//
// LoadRollView.swift
// Aegletes
//
// LoadRollView
//
// Edited on 3/11/26 - Revision 8 - Kept only LoadRollStatusView. Refactored into other files
//

import SwiftUI


// MARK: - Load Roll Sheet View
struct LoadRollStatusView: View {
    let roll: FilmRoll
    let cameraNames: [String]
    @Binding var selectedCamera: String
    @Binding var selectedISO: Double
    let onComplete: (Bool) -> Void  // true = Save, false = Cancel

    var body: some View {
        Form {
            Section(header: Text("Camera")) {
                if cameraNames.isEmpty {
                    Text("No cameras available. Add one in Manage Cameras.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Camera", selection: $selectedCamera) {
                        ForEach(cameraNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
            }

            Section(header: Text("Effective ISO")) {
                Picker("Effective ISO", selection: $selectedISO) {
                    ForEach(FilmRollDatabase.effectiveISOOptions, id: \.self) { iso in
                        Text("EI \(Int(iso))").tag(iso)
                    }
                }
            }
        }
        .navigationTitle("Load Roll")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onComplete(false)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onComplete(true)
                }
                .disabled(
                    selectedCamera
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                    || !FilmRollDatabase.effectiveISOOptions.contains(selectedISO)
                )
            }
        }
    }
}
