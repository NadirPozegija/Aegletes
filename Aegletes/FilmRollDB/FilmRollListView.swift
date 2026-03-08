//
// FilmRollListView.swift
// Aegletes
//
// Main Film DB list: stacks, HeroView usage, expand/collapse, row subheadlines
//

import SwiftUI

struct FilmStack {
    let identity: FilmIdentity
    let rolls: [FilmRoll]
}

struct FilmStackListView: View {
    @EnvironmentObject var filmStore: FilmRollStore

    @State private var expandedStackIDs: Set<FilmIdentity.ID> = []
    @State private var rollBeingEdited: FilmRoll?
    @State private var showingEditSheet: Bool = false

    var body: some View {
        List {
            let stacks = buildStacks(from: filmStore.rolls)

            if stacks.isEmpty {
                Text("No rolls yet. Use Add Roll to create your first entry.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(stacks, id: \.identity.id) { stack in
                    if stack.rolls.count > 1 {
                        // Multi-roll: Hero row (stack) + optional expanded child rows

                        // Hero row (ZStack), with a single swipe action to delete the entire stack
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
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                // Delete the entire stack (all rolls of this identity)
                                expandedStackIDs.remove(stack.identity.id)
                                let all = filmStore.rolls.filter { $0.filmIdentity == stack.identity }
                                all.forEach { filmStore.removeRoll($0) }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }

                        // Expanded entries, sequentially named, each with its own swipe action
                        if expandedStackIDs.contains(stack.identity.id) {
                            ForEach(Array(stack.rolls.enumerated()), id: \.element.id) { index, roll in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Roll \(index + 1)")
                                            .font(.subheadline.weight(.semibold))
                                        rollSubheadline(for: roll)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    rollBeingEdited = roll
                                    showingEditSheet = true
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        filmStore.removeRoll(roll)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
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
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            rollBeingEdited = nil
        }) {
            if let roll = rollBeingEdited {
                NavigationStack {
                    FilmRollEditView(roll: roll) { _ in
                        showingEditSheet = false
                    }
                    .environmentObject(filmStore)
                }
            }
        }
    }

    // MARK: - Stack building & sorting

    private func buildStacks(from rolls: [FilmRoll]) -> [FilmStack] {
        var dict: [FilmIdentity: [FilmRoll]] = [:]
        for roll in rolls {
            dict[roll.filmIdentity, default: []].append(roll)
        }

        // Sort stacks by manufacturer, then stock, then format, then boxISO
        return dict.map { FilmStack(identity: $0.key, rolls: $0.value) }
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

    private func heading(for identity: FilmIdentity) -> String {
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
    private func rollSubheadline(for roll: FilmRoll) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // First subheader line:
            // <Film Type + icon> • ISO <Box ISO>
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
                        EmptyView() // no specific icon defined
                    }
                }

                Text("•")

                Text("ISO \(Int(roll.boxISO))")
            }

            // Second subheader line:
            // <Status + icon> • <Camera? + camera.fill>
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
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }

    private func statusSymbolName(for status: FilmRollStatus) -> String? {
        switch status {
        case .inStorage:
            return "shippingbox.fill"
        case .loaded:
            return "camera.circle.fill"
        case .finished:
            // Closest available SF Symbol to a checkered finish flag
            return "flag.checkered"
        case .developed:
            return "testtube.2"
        case .scanning:
            return "testtube.2"
        case .archived:
            return "film.stack"
        }
    }
}
