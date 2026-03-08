// ManageCamerasView.swift
// Aegletes
//
// Manage camera names: add, list, delete with roll-use warning

import SwiftUI

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
