//
// StackHeroView.swift
// Aegletes
//
// ZStack-based "stacked cards" hero row for multi-roll stacks
//

import SwiftUI

extension Color {
    static let DarkThemeStackColor = Color(red: 0.08, green: 0.12, blue: 0.20) // Darker blue-gray
    static let LightThemeStackColor = Color(red: 0.84, green: 0.90, blue: 0.96) //pale blue
}

struct FilmStackHeroView: View {
    let identity: FilmIdentity
    let rolls: [FilmRoll]
    let isExpanded: Bool
    let showStatusSummary: Bool   // Shows summary of roll status in 'All' view
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
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
            // Background: top card fully opaque gray, others semi-transparent gray. Gray shade depending on system theme
            if colorScheme == .dark{
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTop ? Color.DarkThemeStackColor : Color.LightThemeStackColor.opacity(0.15))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isTop ? Color.LightThemeStackColor : Color.DarkThemeStackColor.opacity(0.15))
            }
            
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
                        .foregroundStyle(.secondary)
                        
                        // NEW: third subheadline only when requested and non-empty
                        if showStatusSummary {
                            let summary = statusSummary
                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text("×\(rolls.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
        .opacity(1.0)
    }
    // Helper function to construct title
    private var heroTitle: String {
        let m = identity.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let s = identity.stock.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = [m, s].filter { !$0.isEmpty }
        if components.isEmpty {
            return "Film Roll"
        }
        return components.joined(separator: " ")
    }
    // Helper function to construct a smart summary of each stack in the 'All' view
    /// e.g: <2 in storage • 1 loaded • 2 scanning>
    private var statusSummary: String {
        guard !rolls.isEmpty else { return "" }
        
        let grouped = Dictionary(grouping: rolls, by: { $0.status })
        var parts: [String] = []
        
        func add(_ status: FilmRollStatus, _ label: String) {
            if let count = grouped[status]?.count, count > 0 {
                parts.append("\(count) \(label)")
            }
        }
        
        add(.inStorage, "in storage")
        add(.loaded, "loaded")
        add(.finished, "finished")
        add(.developed, "developed")
        add(.scanning, "scanning")
        add(.archived, "archived")
        
        return parts.joined(separator: "•")
    }
}
