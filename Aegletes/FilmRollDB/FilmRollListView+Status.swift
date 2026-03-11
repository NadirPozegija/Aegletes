//
// FilmRollListView+Status.swift
// Aegletes
//
// Status UI helpers, status workflow, and LoadRollStatusView
//
// Edited on 3/9/26 - Revision 4 - Subheader: Shot @ ISO (orange/green), status dates via updateStatus,
// and load workflow delegated to FilmRollStore.loadRoll(...).
//

import SwiftUI

extension FilmStackListView {
    // MARK: - Stack building & sorting
    func buildStacks(from rolls: [FilmRoll]) -> [FilmStack] {
        var dict: [FilmIdentity: [FilmRoll]] = [:]
        for roll in rolls {
            dict[roll.filmIdentity, default: []].append(roll)
        }
        return dict
            .map { FilmStack(identity: $0.key, rolls: $0.value) }
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

    func heading(for identity: FilmIdentity) -> String {
        let m = identity.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = identity.stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = [m, s].filter { !$0.isEmpty }
        if components.isEmpty {
            return "Film Roll"
        }
        return components.joined(separator: " ")
    }

    func advanceStatus(for roll: FilmRoll) {
        guard let next = roll.status.nextStatus else {
            return
        }

        // Special case: going to .loaded  require camera + effective ISO
        if next == .loaded {
            prepareLoadSheet(for: roll)
        } else {
            // All other transitions use a confirmation alert
            pendingStatusRoll = roll
            pendingNextStatus = next
            showingStatusAlert = true
        }
    }

    func applyStatusChange(for roll: FilmRoll, to next: FilmRollStatus) {
        // Delegate to FilmRollStore's updateStatus so FilmRoll.updateStatus(to:at:)
        // sets dateLoaded / dateFinished / dateScanned on first transition.
        filmStore.updateStatus(forRollId: roll.id, to: next)
    }

    func statusAlertMessage() -> String {
        guard let next = pendingNextStatus else { return "" }
        return next.transitionPrompt
    }

    // MARK: - Load Roll helpers (special case for .loaded)
    func prepareLoadSheet(for roll: FilmRoll) {
        // Set the item that drives the sheet content
        rollBeingLoaded = roll

        // Do NOT pre-fill a camera; force the user to pick or enter one.
        selectedCameraForLoad = ""

        // Default effective ISO: effectiveISO if valid, else boxISO, else first option
        let defaultISO = (roll.effectiveISO > 0) ? roll.effectiveISO : roll.boxISO
        if FilmRollDatabase.effectiveISOOptions.contains(defaultISO) {
            selectedEffectiveISOForLoad = defaultISO
        } else {
            selectedEffectiveISOForLoad = FilmRollDatabase.effectiveISOOptions.first ?? defaultISO
        }
    }

    func applyLoadStatus(for roll: FilmRoll) {
        // Delegate to shared backend logic in FilmRollStore
        filmStore.loadRoll(
            id: roll.id,
            camera: selectedCameraForLoad,
            effectiveISO: selectedEffectiveISOForLoad
        )
    }
}

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
