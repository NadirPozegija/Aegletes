//
//  FilmRollDetailView.swift
//  Aegletes
//
//  Detail view for a single film roll.
//

import SwiftUI

struct FilmRollDetailView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    let roll: FilmRoll

    @State private var showingEdit = false

    // Local status workflow state (UI only; backend logic is in FilmRollStore)
    @State private var pendingNextStatus: FilmRollStatus?
    @State private var showingStatusAlert = false

    @State private var showingLoadSheet = false
    @State private var selectedCameraForLoad: String = ""
    @State private var selectedEffectiveISOForLoad: Double =
        FilmRollDatabase.effectiveISOOptions.first ?? 100

    /// Always use the latest copy of this roll from the store (so dates/status stay in sync).
    private var liveRoll: FilmRoll {
        filmStore.rolls.first(where: { $0.id == roll.id }) ?? roll
    }

    var body: some View {
        Form {
            if !liveRoll.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section(header: Text("Notes").font(.title)) {
                    Text(liveRoll.notes).font(.headline)
                }
            }

            Section(header: Text("Film").font(.title)) {
                Text("Manufacturer: \(liveRoll.manufacturer)").bold()
                Text("Stock: \(liveRoll.stock)").bold()
                Text("Type: \(liveRoll.filmType.rawValue)").bold()
                Text("Format: \(liveRoll.format.rawValue)").bold()
                Text("Box ISO: \(Int(liveRoll.boxISO))").bold()
                Text("Effective ISO: \(Int(liveRoll.effectiveISO))").bold()
            }

            Section(header: Text("Camera").font(.title)) {
                Text(liveRoll.camera)
            }

            Section(header: Text("Status").font(.title)) {
                Text(liveRoll.status.rawValue).bold()
                if let loaded = liveRoll.dateLoaded {
                    Text("Loaded: \(loaded.formatted(date: .abbreviated, time: .shortened))")
                }
                if let finished = liveRoll.dateFinished {
                    Text("Finished: \(finished.formatted(date: .abbreviated, time: .shortened))")
                }
                if let scanned = liveRoll.dateScanned {
                    Text("Scanned: \(scanned.formatted(date: .abbreviated, time: .shortened))")
                }
            }

            // Bottom "Update Status" button
            Section {
                Button {
                    FilmDBHaptics.medium()      // medium haptic for Update Status button
                    handleUpdateStatusTap()
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: liveRoll.status.actionSymbolName)
                        Text(liveRoll.status.actionTitle)
                            .font(.title2)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(liveRoll.status.actionTintColor)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle(title(for: liveRoll))
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
                FilmRollEditView(roll: liveRoll) { _ in
                    showingEdit = false
                }
                .environmentObject(filmStore)
            }
        }
        // Load Roll sheet (same view as list, but driven by detail state)
        .sheet(isPresented: $showingLoadSheet) {
            NavigationStack {
                LoadRollStatusView(
                    roll: liveRoll,
                    cameraNames: filmStore.cameraNames.filter { $0 != "No camera" },
                    selectedCamera: $selectedCameraForLoad,
                    selectedISO: $selectedEffectiveISOForLoad
                ) { confirmed in
                    if confirmed {
                        filmStore.loadRoll(
                            id: liveRoll.id,
                            camera: selectedCameraForLoad,
                            effectiveISO: selectedEffectiveISOForLoad
                        )
                    }
                    showingLoadSheet = false
                }
            }
        }
        // Confirmation alert for non-loaded status changes
        .alert("Update Status", isPresented: $showingStatusAlert) {
            Button("Cancel", role: .cancel) {
                pendingNextStatus = nil
            }
            Button("Confirm") {
                if let next = pendingNextStatus {
                    filmStore.updateStatus(forRollId: liveRoll.id, to: next)
                }
                pendingNextStatus = nil
            }
        } message: {
            Text(statusAlertMessage(for: pendingNextStatus))
        }
    }

    // MARK: - Title

    private func title(for roll: FilmRoll) -> String {
        let m = roll.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = roll.stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = [m, s].filter { !$0.isEmpty }
        if components.isEmpty {
            return "Film Roll"
        }
        return components.joined(separator: " ")
    }

    // MARK: - Status helpers (centralized FSM in FilmRollStatus+Workflow)

    private func handleUpdateStatusTap() {
        guard let next = liveRoll.status.nextStatus else { return }

        if next == .loaded {
            prepareLoadDefaults()
            showingLoadSheet = true
        } else {
            pendingNextStatus = next
            showingStatusAlert = true
        }
    }

    private func statusAlertMessage(for next: FilmRollStatus?) -> String {
        guard let next else { return "" }
        return next.transitionPrompt
    }

    private func prepareLoadDefaults() {
        // Do NOT pre-fill a camera; force the user to pick/enter one.
        selectedCameraForLoad = ""

        // Default effective ISO: effectiveISO if valid, else boxISO, else first option
        let defaultISO = (liveRoll.effectiveISO > 0)
            ? liveRoll.effectiveISO
            : liveRoll.boxISO

        if FilmRollDatabase.effectiveISOOptions.contains(defaultISO) {
            selectedEffectiveISOForLoad = defaultISO
        } else {
            selectedEffectiveISOForLoad =
                FilmRollDatabase.effectiveISOOptions.first ?? defaultISO
        }
    }
}
