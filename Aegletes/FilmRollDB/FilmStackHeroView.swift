//
// FilmStackHeroView.swift
// Aegletes
//
// ZStack-based "stacked cards" hero row for multi-roll stacks
//

import SwiftUI

struct FilmStackHeroView: View {
    let identity: FilmIdentity
    let rolls: [FilmRoll]
    let isExpanded: Bool

    var body: some View {
        let displayCount = min(rolls.count, 3)

        ZStack(alignment: .topLeading) {
            ForEach(0..<displayCount, id: \.self) { index in
                // depth: 0 = top card, higher = further back
                let depth = CGFloat(displayCount - 1 - index)
                let isTop = (depth == 0)

                heroRow(isTop: isTop)
                    .offset(y: depth * 4)
                    .offset(x: depth * 2)
            }
        }
    }

    private func heroRow(isTop: Bool) -> some View {
        ZStack {
            // Background: top card fully opaque gray, others semi-transparent gray
            RoundedRectangle(cornerRadius: 12)
                .fill(isTop ? Color(red: 0.22, green: 0.22, blue: 0.3).opacity(1.0) : Color(red: 0.44, green: 0.44, blue: 0.6).opacity(0.15))

            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)

            if isTop {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        // Title
                        Text(heroTitle)
                            .font(.headline)

                        // Subtitle: Format • Film Type + icon • ISO
                        HStack(spacing: 4) {
                            // Format
                            Text(identity.format.rawValue)

                            Text("•")

                            // Film Type + icon
                            HStack(spacing: 2) {
                                Text(identity.filmType.rawValue)
                                switch identity.filmType {
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

                            // ISO (Box ISO)
                            Text("ISO \(Int(identity.boxISO))")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("×\(rolls.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .opacity(1.0)
    }

    private var heroTitle: String {
        let m = identity.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = identity.stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = [m, s].filter { !$0.isEmpty }
        if components.isEmpty {
            return "Film Roll"
        }
        return components.joined(separator: " ")
    }
}
