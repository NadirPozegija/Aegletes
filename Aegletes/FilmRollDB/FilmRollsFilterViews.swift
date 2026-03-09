//
// FilmRollsFilterViews.swift
// Aegletes
//
// Segment selector + filtered list wrapper for FilmRolls.
//

import SwiftUI

/// Top-of-screen segment selector (1–5) used to filter FilmRolls.
/// Styled similarly to the Exposure Mode selector.
struct FilmRollsSegmentSelector: View {
    @Binding var selectedSegment: Int

    private let segments: [(id: Int, title: String)] = [
        (1, "All Rolls"),
        (2, "In Storage"),
        (3, "Loaded Rolls"),
        (4, "Processing"),
        (5, "Archived")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.id) { segment in
                let isSelected = (selectedSegment == segment.id)

                Button {
                    if !isSelected {
                        selectedSegment = segment.id
                    }
                } label: {
                    Text(segment.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.green : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            Capsule()
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                .background(
                    Capsule().fill(Color.black.opacity(0.35))
                )
        )
    }
}

/// Wrapper that applies the segment-based filter/sort to all rolls
/// and passes the filtered array into FilmStackListView.
struct FilteredFilmRollsListView: View {
    @EnvironmentObject var filmStore: FilmRollStore
    let selectedSegment: Int

    var body: some View {
        let filtered = filteredRolls(for: selectedSegment, from: filmStore.rolls)
        FilmStackListView(rolls: filtered)
    }

    // MARK: - Filtering & sorting logic

    private func filteredRolls(for segment: Int, from all: [FilmRoll]) -> [FilmRoll] {
        switch segment {
        case 2:
            // 2: In Storage, sorted by dateCreated (newest → oldest)
            return all
                .filter { $0.status == .inStorage }
                .sorted { $0.dateCreated > $1.dateCreated }

        case 3:
            // 3: Loaded, sorted by dateLoaded (newest → oldest)
            return all
                .filter { $0.status == .loaded }
                .sorted {
                    ($0.dateLoaded ?? .distantPast) > ($1.dateLoaded ?? .distantPast)
                }

        case 4:
            // 4: Processing (Finished / Developed / Scanning),
            //    sorted by dateFinished (newest → oldest).
            return all
                .filter {
                    $0.status == .finished ||
                    $0.status == .developed ||
                    $0.status == .scanning
                }
                .sorted {
                    ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast)
                }

        case 5:
            // 5: Archived, sorted by dateScanned (treated as "dateArchived") (newest → oldest)
            return all
                .filter { $0.status == .archived }
                .sorted {
                    ($0.dateScanned ?? .distantPast) > ($1.dateScanned ?? .distantPast)
                }

        default:
            // 1 (or any unknown): All rolls that are NOT archived,
            // sorted by dateCreated (newest → oldest)
            return all
                .filter { $0.status != .archived }
                .sorted { $0.dateCreated > $1.dateCreated }
        }
    }
}
