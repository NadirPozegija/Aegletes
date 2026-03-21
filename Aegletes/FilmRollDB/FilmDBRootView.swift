// FilmDBRootView.swift
// Aegletes
//
// Root entry for the Film DB UI: top bar + navigation shells

import SwiftUI

// Keep FilmIdentity Identifiable conformance in a shared support file (see FilmDBSupport.swift)

struct FilmDBRootView: View {
    @EnvironmentObject var filmStore: FilmRollStore

    /// Callback to return to the meter screen (set by RootView).
    let onBackToMeter: () -> Void

    @State private var showingNewRoll = false
    @State private var showingManageCameras = false
    @State private var selectedSegment: Int = 1   // segment 1–5 for filtering
    
    //States to support JSON I/O
    @State private var showingImportExportActionSheet = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var exportURL: URL?
    @State private var showingImportErrorAlert = false
    @State private var importErrorMessage: String = ""
    
    private func humanReadableImportError(_ error: Error) -> String {
        if let loadError = error as? FilmRollDatabase.LoadError {
            switch loadError {
            case .fileNotFound:
                return "The selected file could not be found."
            case .dataReadFailed(let underlying):
                return "The file could not be read. (\(underlying.localizedDescription))"
            case .decodeFailed:
                return "The file is not a valid Aegletes film database JSON."
            }
        } else {
            return "The file could not be imported. (\(error.localizedDescription))"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom top bar with three aligned buttons
                HStack {
                    // Left: back to meter
                    Button {
                        FilmDBHaptics.light()
                        onBackToMeter()
                    } label: {
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
                    Button {
                        FilmDBHaptics.light()
                        showingManageCameras = true
                    } label: {
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

                    // Right: I/O JSON
                    Button {
                        FilmDBHaptics.light()
                        showingImportExportActionSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .fontWeight(.light)
                            Text("I/O JSON")
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
                .foregroundStyle(.primary)
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color(.systemBackground).opacity(0.75))

                Divider()

                // Header above the list
                HStack {
                    Text("Film Rolls")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        FilmDBHaptics.light()
                        showingNewRoll = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "list.and.film")
                                .fontWeight(.light)
                            Text("Add Roll(s)")
                        }
                        .font(.subheadline.weight(.semibold))
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
                .padding(.horizontal)
                .padding(.top, 4)

                // Segment selector bar (1–5)
                FilmRollsSegmentSelector(selectedSegment: $selectedSegment)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                // Main content: film stacks list with HeroView for multi-roll stacks
                FilteredFilmRollsListView(selectedSegment: selectedSegment)
            }
            .navigationBarHidden(true)
        }
        .confirmationDialog(
            "Film Database",
            isPresented: $showingImportExportActionSheet,
            titleVisibility: .visible
        ) {
            Button("Export JSON") {
                filmStore.saveNow()
                exportURL = filmStore.databaseStoreURL
                showingExportSheet = true
            }

            Button("Import JSON") {
                showingImportPicker = true
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("What would you like to do?")
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ExportJSONView(fileURL: url)
            } else {
                Text("No export file available.")
            }
        }
        .sheet(isPresented: $showingImportPicker) {
            ImportJSONView { url in
                if let url = url {
                    if let error = filmStore.importFromJSON(at: url) {
                        importErrorMessage = humanReadableImportError(error)
                        showingImportErrorAlert = true
                    }
                }
            }
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
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ExportJSONView(fileURL: url)
            } else {
                Text("No export file available.")
            }
        }
        .alert("Import Failed", isPresented: $showingImportErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage.isEmpty
                 ? "The file could not be imported. Make sure it is a valid film database file."
                 : importErrorMessage)
        }
    }
}
