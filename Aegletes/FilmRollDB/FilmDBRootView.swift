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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom top bar with three aligned buttons
                HStack {
                    // Left: back to meter
                    Button {
                        FilmDBHaptics.light()      // <- light haptic
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
                        FilmDBHaptics.light()      // <- light haptic
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

                    // Right: Add Roll
                    Button {
                        FilmDBHaptics.light()      // <- light haptic
                        showingNewRoll = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "film.roll.plus")
                            Text("Add Roll(s)")
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
                        .font(.largeTitle).fontWeight(.bold)
                    Spacer()
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
