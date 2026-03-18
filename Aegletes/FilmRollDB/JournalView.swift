////  JournalView.swift
//   Aegletes
////
////  Collapsible journal section for a single FilmRoll.
//

import SwiftUI

struct JournalView: View {
    /// The roll whose journal we are displaying.
    let roll: FilmRoll

    /// Controls whether the journal entries are visible.
    @State private var isExpanded: Bool = false
    
    /// Called when the user deletes an entry.
    let onDeleteEntry: (FilmExposureEntry) -> Void

    var body: some View {
        Section {
            // Tappable header row: "Journal" with entry count + chevron
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Journal")
                        .font(.headline)

                    Spacer()

                    if !roll.journal.isEmpty {
                        Text("\(roll.journal.count) entr\(roll.journal.count == 1 ? "y" : "ies")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                if roll.journal.isEmpty {
                    Text("No saved frames for this roll")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedEntries) { entry in
                        journalEntryView(entry)
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDeleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Sorting

    /// Entries sorted by (frameNumber, dateCaptured) for stable display.
    private var sortedEntries: [FilmExposureEntry] {
        roll.journal.sorted { a, b in
            switch (a.frameNumber, b.frameNumber) {
            case let (fa?, fb?):
                if fa != fb { return fa < fb }
                return a.dateCaptured < b.dateCaptured
            case (nil, nil):
                return a.dateCaptured < b.dateCaptured
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            }
        }
    }
    
    // MARK: - Entry rendering

    private func journalEntryView(_ entry: FilmExposureEntry) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Line 1: Frame #
            if let frame = entry.frameNumber {
                Text("Frame \(frame)")
                    .font(.headline)
            } else {
                Text("Frame")
                    .font(.headline)
            }
            
            Spacer()

            Text(entry.dateCaptured.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Line 2: f/(f stop) • shutter s • ISO N
            Text(formattedExposure(for: entry))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Line 3: notes (if any)
            let trimmedNotes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty {
                Text(trimmedNotes)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Formatting helpers

    /// Formats exposure as: f/8.0 • 1/60s • ISO 800
    private func formattedExposure(for entry: FilmExposureEntry) -> String {
        // Aperture: f/8.0
        let apertureString = String(format: "%.1f", entry.aperture)

        // Shutter: 1/60s or 4s
        let shutter = entry.shutter
        let shutterString: String
        if shutter < 1.0 && shutter > 0 {
            let denom = max(1, Int(round(1.0 / shutter)))
            shutterString = "1/\(denom)"
        } else {
            shutterString = String(Int(round(shutter)))
        }

        let isoInt = Int(round(entry.iso))

        return "f/\(apertureString) • \(shutterString)s • ISO \(isoInt)"
    }
}
