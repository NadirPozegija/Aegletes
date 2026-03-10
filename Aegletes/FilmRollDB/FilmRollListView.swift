//
// FilmRollListView.swift
// Aegletes
//
// Main Film DB list: stacks, HeroView usage, expand/collapse
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

    // UI state
    @State var expandedStackIDs: Set<FilmIdentity.ID> = []

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

    var body: some View {
        List {
            let stacks = buildStacks(from: rolls)

            if stacks.isEmpty {
                Text("No rolls yet. Use Add Roll(s) to create your first entry.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(stacks, id: \.identity.id) { stack in
                    if stack.rolls.count > 1 {
                        // Multi-roll: Hero row (stack) + optional expanded child rows

                        FilmStackHeroView(
                            identity: stack.identity,
                            rolls: stack.rolls,
                            isExpanded: expandedStackIDs.contains(stack.identity.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if expandedStackIDs.contains(stack.identity.id) {
                                expandedStackIDs.remove(stack.identity.id)
                            } else {
                                expandedStackIDs.insert(stack.identity.id)
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
                                Image(systemName: "trash")
                            }
                        }

                        // Expanded entries, sequentially named, each with its own swipe actions
                        if expandedStackIDs.contains(stack.identity.id) {
                            ForEach(Array(stack.rolls.enumerated()), id: \.element.id) { index, roll in
                                NavigationLink(destination: FilmRollDetailView(roll: roll)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Roll \(index + 1)")
                                                .font(.subheadline.weight(.semibold))
                                            rollSubheadline(for: roll)
                                        }
                                        Spacer()
                                    }
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
                                        Image(systemName: "trash")
                                    }

                                    // Advance status for this specific roll
                                    Button {
                                        FilmDBHaptics.medium()
                                        advanceStatus(for: roll)
                                    } label: {
                                        Image(systemName: updateStatusSymbol(for: roll.status))
                                    }
                                    .tint(updateStatusTint(for: roll.status))
                                }
                            }
                        }
                    } else if let roll = stack.rolls.first {
                        // Single roll: normal row that goes straight to detail
                        NavigationLink(destination: FilmRollDetailView(roll: roll)) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(heading(for: stack.identity))
                                        .font(.headline)
                                    rollSubheadline(for: roll)
                                }
                                Spacer()
                            }
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
                                Image(systemName: "trash")
                            }

                            // Advance status for this roll
                            Button {
                                FilmDBHaptics.medium()
                                advanceStatus(for: roll)
                            } label: {
                                Image(systemName: updateStatusSymbol(for: roll.status))
                            }
                            .tint(updateStatusTint(for: roll.status))
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
            pendingDeletionRolls.count > 1 ? "Delete Stack?" : "Delete Roll?",
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
    }
}
