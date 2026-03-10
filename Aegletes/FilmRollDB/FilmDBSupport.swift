// FilmDBSupport.swift
// Aegletes
//
// Shared helpers for Film DB UI

import Foundation
import SwiftUI
import UIKit

// Identifiable key for film stacks used in UI
extension FilmIdentity: Identifiable {
    var id: String {
        "\(manufacturer)|\(stock)|\(filmType.rawValue)|\(format.rawValue)|\(boxISO)"
    }
}

enum FilmDBHaptics {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    static func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
}
