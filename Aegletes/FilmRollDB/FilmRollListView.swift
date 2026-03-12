//
//  FilmRollListView.swift
//  Aegletes
//
//  Main Film DB list: stacks, HeroView usage, expand/collapse
//

import SwiftUI

struct FilmStack {
    let identity: FilmIdentity
    let rolls: [FilmRoll]
}

struct FilmStackListView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    @Environment(\.colorScheme) private var colorScheme

    /// Rolls to display (already filtered/sorted by the caller).
    let rolls: [FilmRoll]
    /// Whether to show the stack status summary line under the hero.
    let showStatusSummary: Bool    // NEW

    // UI state
    @State private var expandedStackIDs: Set<FilmIdentity> = []

    // For generic status confirmation (non-loaded transitions)
    @State var pendingStatusRoll: FilmRoll?
    @State var pendingNextStatus: FilmRollStatus?
    @State var showingStatusAlert: Bool = false

    // For special "Load roll" sheet when transitioning to .loaded
    @State var rollBeingLoaded: FilmRoll?
    @State var selectedCameraForLoad: String = ""
    @State var selectedEffectiveISOForLoad: Double = 0

    // Secondary confirmation for deletion of a Roll Entry
    @State private var pendingDeletionRolls: [FilmRoll] = []
    @State private var showingDeleteConfirmation = false
    
    // For the ability to change roll count with a swipe action on the Parent HeroView card
    @State private var showingStackSizeSheet = false
    @State private var stackBeingResized: FilmIdentity?
    @State private var newStackSizeText: String = ""

    // Helper function to facilitate the swipe action on the Parent HeroView card to change roll count
    private func applyStackSizeChange() {
        guard let identity = stackBeingResized,
              let target = Int(newStackSizeText)
        else {
            showingStackSizeSheet = false
            stackBeingResized = nil
            return
        }

        filmStore.setStackCount(for: identity, to: target)

        showingStackSizeSheet = false
        stackBeingResized = nil
    }
    
    var body: some View {
        List {
            let stacks = buildStacks(from: rolls)

            if stacks.isEmpty {
                Text("No rolls yet.\nUse Add Roll(s) to create your first entry.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(stacks, id: \.identity) { stack in
                    if stack.rolls.count > 1 {
                        // Multi-roll: Hero row (stack) + optional expanded child rows
                        FilmStackHeroView(
                            identity: stack.identity,
                            rolls: stack.rolls,
                            isExpanded: expandedStackIDs.contains(stack.identity),
                            showStatusSummary: showStatusSummary
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if expandedStackIDs.contains(stack.identity) {
                                expandedStackIDs.remove(stack.identity)
                            } else {
                                expandedStackIDs.insert(stack.identity)
                            }
                            FilmDBHaptics.light()   // hero expand/collapse
                        }
                        // Delete the whole stack
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                let all = filmStore.rolls.filter { $0.filmIdentity == stack.identity }
                                pendingDeletionRolls = all
                                showingDeleteConfirmation = true
                                FilmDBHaptics.light()
                            } label: {
                                SwipeActionLabel(systemName: "trash", title: "Delete")
                            }
                            
                            // Adjust stack size (only on hero row)
                            Button {
                                stackBeingResized = stack.identity
                                newStackSizeText = String(stack.rolls.count)
                                showingStackSizeSheet = true
                                FilmDBHaptics.light()
                            } label: {
                                Image(systemName: "plusminus.circle")
                            }
                            .tint(.brown)
                        }

                        // Expanded entries, sequentially named, each with its own swipe actions
                        if expandedStackIDs.contains(stack.identity) {
                            ForEach(Array(stack.rolls.enumerated()), id: \.element.id) { index, roll in
                                NavigationLink(destination: FilmRollDetailView(roll: roll)) {
                                    FilmRollRowView(
                                        title: "Roll \(index + 1)",
                                        roll: roll,
                                        titleFont: .subheadline.weight(.semibold)
                                    )
                                }
                                //have the sub rows inherit the color of the top card of the stack for clarity
                                .listRowBackground(
                                    colorScheme == .light ?
                                        Color.LightThemeStackColor : Color.DarkThemeStackColor
                                )
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        FilmDBHaptics.light()  // navigate to detail
                                    }
                                )
                                .swipeActions(edge: .trailing) {
                                    // Delete just this roll from larger stack
                                    Button(role: .destructive) {
                                        pendingDeletionRolls = [roll]
                                        showingDeleteConfirmation = true
                                        FilmDBHaptics.light()
                                    } label: {
                                        SwipeActionLabel(systemName: "trash", title: "Delete")
                                    }
                                    // Advance status for this specific roll
                                    Button {
                                        FilmDBHaptics.medium()
                                        advanceStatus(for: roll)
                                    } label: {
                                        SwipeActionLabel(
                                            systemName: roll.status.actionSymbolName, title: roll.status.actionTitle
                                        )
                                    }
                                    .tint(roll.status.actionTintColor)
                                }
                            }
                        }
                    } else if let roll = stack.rolls.first {
                        // Single roll: normal row that goes straight to detail
                        NavigationLink(destination: FilmRollDetailView(roll: roll)) {
                            FilmRollRowView(
                                title: heading(for: stack.identity),
                                roll: roll,
                                titleFont: .headline
                            )
                        }
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                FilmDBHaptics.light()  // navigate to detail
                            }
                        )
                        .swipeActions(edge: .trailing) {
                            // Delete this single roll
                            Button(role: .destructive) {
                                pendingDeletionRolls = [roll]
                                showingDeleteConfirmation = true
                                FilmDBHaptics.light()
                            } label: {
                                SwipeActionLabel(systemName: "trash", title: "Delete")
                            }
                            // Advance status for this roll
                            Button {
                                FilmDBHaptics.medium()
                                advanceStatus(for: roll)
                            } label: {
                                SwipeActionLabel(
                                    systemName: roll.status.actionSymbolName, title: roll.status.actionTitle
                                )
                            }
                            .tint(roll.status.actionTintColor)
                        }
                    }
                }
            }
        }
        // Load Roll sheet (when transitioning to .loaded), driven by rollBeingLoaded
        .sheet(item: $rollBeingLoaded) { roll in
            NavigationStack {
                LoadRollStatusView(
                    roll: roll,
                    // Exclude "No camera" from the selectable list
                    cameraNames: filmStore.cameraNames.filter { $0 != "No camera" },
                    selectedCamera: $selectedCameraForLoad,
                    selectedISO: $selectedEffectiveISOForLoad
                ) { confirmed in
                    if confirmed {
                        applyLoadStatus(for: roll)
                    }
                    // Dismiss by clearing the item
                    rollBeingLoaded = nil
                }
            }
        }
        // Confirmation alert for non-loaded status changes
        .alert("Update Status", isPresented: $showingStatusAlert) {
            Button("Cancel", role: .cancel) {
                pendingStatusRoll = nil
                pendingNextStatus = nil
            }
            Button("Confirm") {
                if let roll = pendingStatusRoll, let next = pendingNextStatus {
                    applyStatusChange(for: roll, to: next)
                }
                pendingStatusRoll = nil
                pendingNextStatus = nil
            }
        } message: {
            Text(statusAlertMessage())
        }
        .alert(
            pendingDeletionRolls.count > 1 ?
                "Delete Stack?" : "Delete Roll?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                pendingDeletionRolls.removeAll()
            }
            Button("Delete", role: .destructive) {
                for roll in pendingDeletionRolls {
                    filmStore.removeRoll(roll)
                }
                FilmDBHaptics.rigid()
                pendingDeletionRolls.removeAll()
            }
        } message: {
            if pendingDeletionRolls.count > 1 {
                Text("Are you sure you want to delete this stack of \(pendingDeletionRolls.count) rolls?")
            } else if let roll = pendingDeletionRolls.first {
                let manufacturer = roll.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
                let stock = roll.stock.trimmingCharacters(in: .whitespacesAndNewlines)
                let label = [manufacturer, stock].filter { !$0.isEmpty }.joined(separator: " ")
                Text(label.isEmpty
                     ? "Are you sure you want to delete this roll?"
                     : "Are you sure you want to delete this roll of \n\(label)?")
            } else {
                Text("Are you sure you want to delete this roll?")
            }
        }
        .sheet(isPresented: $showingStackSizeSheet) {
            NavigationStack {
                VStack {
                    Form {
                        Section(
                            header: Text("Update the number of rolls this stack has:")
                        ) {
                            TextField("Number of rolls",
                                      text: $newStackSizeText)
                                .keyboardType(.numberPad)
                        }
                    }

                    HStack {
                        Button("Cancel") {
                            showingStackSizeSheet = false
                            stackBeingResized = nil
                        }
                        .foregroundStyle(.red)

                        Spacer()

                        Button("Save") {
                            applyStackSizeChange()
                        }
                        .disabled(Int(newStackSizeText) == nil)
                    }
                    .padding()
                }
                .navigationTitle("Stack Size")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

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

struct SwipeActionLabel: View {
    let systemName: String
    let title: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
            Text(title)
                .font(.caption2)
        }
    }
}
