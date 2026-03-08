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
}
