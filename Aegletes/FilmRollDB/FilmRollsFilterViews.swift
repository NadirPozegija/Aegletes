//
// FilmRollsFilterViews.swift
// Aegletes
//
// Segment selector + filtered list wrapper for FilmRolls.
//

import SwiftUI
import UIKit

/// Top-of-screen segment selector (1–5) used to filter FilmRolls.
/// Styled similarly to the Exposure Mode selector.
struct FilmRollsSegmentSelector: View {
    @Binding var selectedSegment: Int

    private let segments: [(id: Int, title: String)] = [
        (1, "All"),
        (2, "In Storage"),
        (3, "Loaded"),
        (4, "Processing"),
        (5, "Archived")
    ]

    // Scalable bar height, derived from screen height (≈ screenHeight / 12),
    // clamped to a reasonable range so it never gets huge or tiny.
    @State private var barHeight: CGFloat = 32

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments, id: \.id) { segment in
                let isSelected = (selectedSegment == segment.id)

                Button {
                    if !isSelected {
                        selectedSegment = segment.id
                    }
                } label: {
                    ZStack {
                        // Fill the entire segment area inside the capsule
                        (isSelected ? Color(red: 0.7, green: 0.7, blue: 0.19).opacity(0.85) : Color.clear)

                        Text(segment.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? Color.primary : Color.primary.opacity(0.75))
                            .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: barHeight)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
        )
        .onAppear {
            updateBarHeightFromScreen()
        }
    }

    /// Compute bar height as roughly 1/15 of the current screen height,
    /// using a UIScreen obtained via windowScene (no UIScreen.main).
    private func updateBarHeightFromScreen() {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let screen = scene.screen as UIScreen?
        else { return }

        let h = screen.bounds.height / 12.0
        // Clamp to something sensible so it doesn't get extreme on unusual screens
        barHeight = max(28, min(h, 60))
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
