//
// FilmRollListView+Status.swift
// Aegletes
//
// Status UI helpers, status workflow, and LoadRollStatusView
//
// Edited on 3/9/26 - Revision 4 - Subheader: Shot @ ISO (orange/green), status dates via updateStatus.
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

    // MARK: - Subheadline builder with SF Symbols (two lines)
    @ViewBuilder
    func rollSubheadline(for roll: FilmRoll) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // First subheader line:
            // <Film Type + icon> • ISO <Box ISO>   (inStorage)
            // <Film Type + icon> • Shot @ ISO <Effective ISO>   (other statuses)
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text(roll.filmType.rawValue)
                    switch roll.filmType {
                    case .color:
                        Image(systemName: "rainbow")
                            .symbolRenderingMode(.multicolor)
                    case .bw:
                        Image(systemName: "square.tophalf.filled")
                    case .slide:
                        EmptyView()
                    }
                }

                Text("•")

                let isInStorage = (roll.status == .inStorage)
                let isPushedOrPulled = roll.effectiveISO != roll.boxISO

                if isInStorage {
                    // Original behavior for rolls still in storage
                    Text("ISO \(Int(roll.boxISO))")
                        .foregroundColor(.secondary)
                } else {
                    // Loaded / finished / developed / scanning / archived
                    let label = "Shot @ ISO \(Int(roll.effectiveISO))"
                    Text(label)
                        .foregroundColor(isPushedOrPulled ? .orange : .green)
                }
            }
            .foregroundColor(.secondary)

            // Second subheader line:
            // <Status + icon> • <Camera?> + camera.fill
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text(roll.status.rawValue)
                    if let statusSymbol = statusSymbolName(for: roll.status) {
                        Image(systemName: statusSymbol)
                    }
                }

                let cam = roll.camera.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasCamera = !cam.isEmpty && cam != "No camera"
                if hasCamera {
                    Text("•")
                    HStack(spacing: 2) {
                        Text(cam)
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .foregroundColor(.secondary)
        }
        .font(.subheadline)
    }

    func statusSymbolName(for status: FilmRollStatus) -> String? {
        switch status {
        case .inStorage:
            return "shippingbox.fill"
        case .loaded:
            return "camera.circle.fill"
        case .finished:
            return "flag.checkered"
        case .developed:
            return "testtube.2"
        case .scanning:
            return "barcode.viewfinder"
        case .archived:
            return "film.stack"
        }
    }

    // MARK: - Update Status appearance (icon + tint) for swipe action
    func updateStatusSymbol(for status: FilmRollStatus) -> String {
        switch status {
        case .inStorage:
            return "camera.circle.fill"
        case .loaded:
            return "flag.checkered"
        case .finished:
            return "testtube.2"
        case .developed:
            return "barcode.viewfinder"
        case .scanning:
            return "film.stack"
        case .archived:
            return "barcode.viewfinder"
        }
    }

    func updateStatusTint(for status: FilmRollStatus) -> Color {
        switch status {
        case .inStorage:
            return .yellow
        case .loaded:
            return .green
        case .finished:
            return .blue
        case .developed:
            return .indigo
        case .scanning:
            return .red
        case .archived:
            return .indigo
        }
    }

    // MARK: - Status progression helpers
    func advanceStatus(for roll: FilmRoll) {
        guard let next = nextStatus(after: roll.status) else {
            return
        }

        // Special case: going to .loaded → require camera + effective ISO
        if next == .loaded {
            prepareLoadSheet(for: roll)
        } else {
            // All other transitions use a confirmation alert
            pendingStatusRoll = roll
            pendingNextStatus = next
            showingStatusAlert = true
        }
    }

    func nextStatus(after status: FilmRollStatus) -> FilmRollStatus? {
        // In Storage -> Loaded -> Finished -> Developed -> Scanning -> Archived
        // Archived -> Scanning (backwards)
        switch status {
        case .inStorage:
            return .loaded
        case .loaded:
            return .finished
        case .finished:
            return .developed
        case .developed:
            return .scanning
        case .scanning:
            return .archived
        case .archived:
            return .scanning
        }
    }

    func applyStatusChange(for roll: FilmRoll, to next: FilmRollStatus) {
        // Delegate to FilmRollStore's updateStatus so FilmRoll.updateStatus(to:at:)
        // sets dateLoaded / dateFinished / dateScanned on first transition.
        filmStore.updateStatus(forRollId: roll.id, to: next)
    }

    func statusAlertMessage() -> String {
        guard let next = pendingNextStatus else { return "" }
        switch next {
        case .inStorage:
            return "Return this roll to storage?"
        case .loaded:
            return "Load this roll into a camera?"
        case .finished:
            return "Mark this roll as Finished?"
        case .developed:
            return "Mark this roll as Developed?"
        case .scanning:
            return "Mark this roll as Scanning?"
        case .archived:
            return "Archive this roll?"
        }
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
        let trimmedCamera = selectedCameraForLoad.trimmingCharacters(in: .whitespacesAndNewlines)

        // Require a real camera name (not empty, not "No camera") and a valid effective ISO.
        guard
            !trimmedCamera.isEmpty,
            trimmedCamera != "No camera",
            FilmRollDatabase.effectiveISOOptions.contains(selectedEffectiveISOForLoad)
        else {
            return
        }

        // Start from the existing roll, adjust camera/EI, then use FilmRoll.updateStatus
        // so dateLoaded is set when first transitioning to .loaded.
        var updated = roll
        updated.camera = trimmedCamera
        updated.effectiveISO = selectedEffectiveISOForLoad
        updated.updateStatus(to: .loaded)

        filmStore.updateRoll(updated)
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
