//
//  FilmRollSubheadlineView.swift
//  Aegletes
//
//  Two-line subheadline for a FilmRoll (type, ISO/EI, status, camera).
//

import SwiftUI

struct FilmRollSubheadlineView: View {
    let roll: FilmRoll

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // First subheader line:
            //   ISO    (inStorage)
            //   Shot @ ISO    (other statuses)
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
                        Image(systemName: "rainbow")
                            .symbolRenderingMode(.multicolor)
                    }
                }

                Text("•")

                let isInStorage = (roll.status == .inStorage)
                let isPushedOrPulled = roll.effectiveISO != roll.boxISO

                if isInStorage {
                    // Original behavior for rolls still in storage
                    Text("ISO \(Int(roll.boxISO))")
                } else {
                    // Loaded / finished / developed / scanning / archived
                    let label = "Shot @ ISO \(Int(roll.effectiveISO))"
                    Text(label)
                        .foregroundStyle(isPushedOrPulled ? .orange : .green)
                }
            }
            .foregroundStyle(.secondary)

            // Second subheader line:
            //    + camera.fill if there is a camera
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text(roll.status.rawValue)
                    if let statusSymbol = roll.status.statusSymbolName {
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
            .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
